import { NodeSdk } from '@effect/opentelemetry';
import { BatchSpanProcessor, ConsoleSpanExporter } from '@opentelemetry/sdk-trace-base';

// Console-based observability for development
// Traces will be printed to the console with timing information
//
// To upgrade to Jaeger or another OTLP backend later:
// 1. npm install @opentelemetry/exporter-trace-otlp-http
// 2. Replace ConsoleSpanExporter with OTLPTraceExporter
// 3. Configure the OTLP endpoint URL (e.g., http://localhost:4318/v1/traces)
export const ObservabilityLive = NodeSdk.layer(() => ({
  resource: {
    serviceName: 'datalk',
    serviceVersion: '0.1.0',
  },
  spanProcessor: new BatchSpanProcessor(new ConsoleSpanExporter()),
}));
