import { NodeSdk } from '@effect/opentelemetry';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-proto';


//  podman run --name jaeger \
//   -e COLLECTOR_ZIPKIN_HOST_PORT=:9411 \
//   -e COLLECTOR_OTLP_ENABLED=true \
//   -p 6831:6831/udp \
//   -p 6832:6832/udp \
//   -p 5778:5778 \
//   -p 16686:16686 \
//   -p 4317:4317 \
//   -p 4318:4318 \
//   -p 14250:14250 \
//   -p 14268:14268 \
//   -p 14269:14269 \
//   -p 9411:9411 \
//   --rm \
//   jaegertracing/all-in-one:latest
export const ObservabilityLive = NodeSdk.layer(() => ({
  resource: {
    serviceName: 'datalk',
    serviceVersion: '0.1.0',
  },
  spanProcessor: new BatchSpanProcessor(new OTLPTraceExporter()),
}));
