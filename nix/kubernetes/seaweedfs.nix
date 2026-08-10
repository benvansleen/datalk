{
  flake.modules.kubernetes.seaweedfs =
    { config, lib, ... }:
    {
      options.modules.seaweedfs.enable = lib.mkEnableOption "ephemeral SeaweedFS S3 storage";

      ## TODO: helm install; operator?
      config = lib.mkIf config.modules.seaweedfs.enable {
        applications.seaweedfs = {
          namespace = "datalk";
          createNamespace = true;
          resources = {
            services.seaweedfs-s3.spec = {
              type = "ClusterIP";
              selector.app = "seaweedfs";
              ports.s3 = {
                port = 8333;
                targetPort = "s3";
              };
            };

            deployments.seaweedfs.spec = {
              replicas = 1;
              selector.matchLabels.app = "seaweedfs";
              template = {
                metadata.labels.app = "seaweedfs";
                spec = {
                  containers.seaweedfs = {
                    image = "chrislusf/seaweedfs:4.41";
                    args = [
                      "server"
                      "-s3"
                      "-dir=/data"
                      "-s3.port=8333"
                    ];
                    ports.s3.containerPort = 8333;
                    volumeMounts = [
                      {
                        name = "data";
                        mountPath = "/data";
                      }
                    ];
                  };
                  volumes.data.emptyDir = { };
                };
              };
            };
          };
        };
      };
    };
}
