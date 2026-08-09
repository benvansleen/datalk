{
  flake.modules.kubernetes.observability =
    { config, lib, ... }:
    {
      options.modules.observability.enable = lib.mkEnableOption "local observability runtime";

      config = lib.mkIf config.modules.observability.enable {
        applications = {
          datalk.resources = {
            configMaps.otel-exporter-env.data = {
              OTEL_EXPORTER_OTLP_ENDPOINT = "http://otel-collector.observability.svc.cluster.local:4318";
              OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
            };

            deployments.datalk.spec.template.spec.containers.datalk = {
              env = [
                {
                  name = "OTEL_SERVICE_NAME";
                  value = "datalk";
                }
              ];
              envFrom = [
                { configMapRef.name = "otel-exporter-env"; }
              ];
            };
          };

          python-server.resources.deployments.python-server.spec.template.spec.containers.python-server = {
            env = [
              {
                name = "OTEL_SERVICE_NAME";
                value = "lis-python-server";
              }
            ];
            envFrom = [
              { configMapRef.name = "otel-exporter-env"; }
            ];
          };

          observability = {
            namespace = "observability";
            createNamespace = true;

            resources = {
              configMaps.otel-collector-config.data."config.yaml" = /* yaml */ ''
                receivers:
                  otlp:
                    protocols:
                      grpc:
                        endpoint: 0.0.0.0:4317
                      http:
                        endpoint: 0.0.0.0:4318

                processors:
                  memory_limiter:
                    check_interval: 1s
                    limit_mib: 400
                    spike_limit_mib: 100
                  batch: {}

                exporters:
                  otlp/jaeger:
                    endpoint: jaeger.observability.svc.cluster.local:4317
                    tls:
                      insecure: true

                service:
                  pipelines:
                    traces:
                      receivers: [otlp]
                      processors: [memory_limiter, batch]
                      exporters: [otlp/jaeger]
              '';

              services = {
                otel-collector.spec = {
                  type = "ClusterIP";
                  selector.app = "otel-collector";
                  ports = {
                    otlp-grpc = {
                      port = 4317;
                      targetPort = "otlp-grpc";
                    };
                    otlp-http = {
                      port = 4318;
                      targetPort = "otlp-http";
                    };
                  };
                };

                jaeger.spec = {
                  type = "ClusterIP";
                  selector.app = "jaeger";
                  ports = {
                    ui = {
                      port = 16686;
                      targetPort = "ui";
                    };
                    otlp-grpc = {
                      port = 4317;
                      targetPort = "otlp-grpc";
                    };
                  };
                };
              };

              deployments = {
                otel-collector.spec = {
                  replicas = 1;
                  selector.matchLabels.app = "otel-collector";
                  template = {
                    metadata.labels.app = "otel-collector";
                    spec = {
                      containers.otel-collector = {
                        image = "otel/opentelemetry-collector-contrib:0.130.1@sha256:9c247564e65ca19f97d891cca19a1a8d291ce631b890885b44e3503c5fdb3895";
                        args = [ "--config=/etc/otelcol-contrib/config.yaml" ];
                        ports = {
                          otlp-grpc.containerPort = 4317;
                          otlp-http.containerPort = 4318;
                        };
                        resources.limits.memory = "512Mi";
                        volumeMounts.config = {
                          name = "config";
                          mountPath = "/etc/otelcol-contrib/config.yaml";
                          subPath = "config.yaml";
                          readOnly = true;
                        };
                      };
                      volumes.config = {
                        name = "config";
                        configMap.name = "otel-collector-config";
                      };
                    };
                  };
                };

                jaeger.spec = {
                  replicas = 1;
                  selector.matchLabels.app = "jaeger";
                  template = {
                    metadata.labels.app = "jaeger";
                    spec.containers.jaeger = {
                      image = "jaegertracing/all-in-one:1.68.0@sha256:6279882637ae03e70f519965d2ba5ca84cb785f4baf4f0d7237e827a37c33a42";
                      env = [
                        {
                          name = "COLLECTOR_OTLP_ENABLED";
                          value = "true";
                        }
                      ];
                      ports = {
                        ui.containerPort = 16686;
                        otlp-grpc.containerPort = 4317;
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
}
