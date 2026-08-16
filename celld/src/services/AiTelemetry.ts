import type { Telemetry } from 'ai';
import { Effect, Layer } from 'effect';
import { Observability, ObservabilityLive } from './Observability';

const makeService = (observability: Observability) => {
  const make = (): Telemetry => ({
    onLanguageModelCallEnd: (event) => {
      observability.emit('ai.model.call', 'success', {
        'gen_ai.provider.name': event.provider,
        'gen_ai.request.model': event.modelId,
        'gen_ai.response.finish_reason': event.finishReason,
        'gen_ai.usage.input_tokens': event.usage.inputTokens ?? 0,
        'gen_ai.usage.output_tokens': event.usage.outputTokens ?? 0,
        'gen_ai.usage.total_tokens': event.usage.totalTokens ?? 0,
        'gen_ai.response.duration_ms': event.performance.responseTimeMs,
        'gen_ai.response.time_to_first_output_ms': event.performance.timeToFirstOutputMs,
      });
    },
    onToolExecutionEnd: (event) => {
      observability.emit(
        'ai.tool.execute',
        event.toolOutput.type === 'tool-error' ? 'error' : 'success',
        {
          'gen_ai.tool.name': event.toolCall.toolName,
          'gen_ai.tool.duration_ms': event.toolExecutionMs,
        },
      );
    },
  });

  return { make } as const;
};

export class AiTelemetry extends Effect.Service<AiTelemetry>()('app/AiTelemetry', {
  effect: Effect.map(Observability, makeService),
  dependencies: [ObservabilityLive],
}) {}

export const AiTelemetryLive = AiTelemetry.Default;

export const AiTelemetryFromObservability = Layer.effect(
  AiTelemetry,
  Effect.map(Observability, (service) => new AiTelemetry(makeService(service))),
);
