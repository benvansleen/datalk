import { Effect, Layer } from 'effect';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AiTelemetry, AiTelemetryFromObservability } from '../src/services/AiTelemetry';
import { makeObservabilityLayer, Observability } from '../src/services/Observability';

const testLayer = () => {
  const observability = makeObservabilityLayer();
  return Layer.merge(
    observability,
    AiTelemetryFromObservability.pipe(Layer.provide(observability)),
  );
};

afterEach(() => {
  vi.restoreAllMocks();
});

describe('application observability services', () => {
  it('emits bounded completion records without changing the effect result', async () => {
    const output: string[] = [];
    vi.spyOn(console, 'log').mockImplementation((line) => output.push(String(line)));

    const result = await Effect.runPromise(
      Effect.gen(function* () {
        const observability = yield* Observability;
        return yield* observability.track('app.test', Effect.succeed('ok'), {
          safe: 'x'.repeat(200),
          ignored: undefined,
        });
      }).pipe(Effect.provide(makeObservabilityLayer())),
    );

    expect(result).toBe('ok');
    expect(JSON.parse(output[0])).toMatchObject({
      telemetry: 'application',
      operation: 'app.test',
      outcome: 'success',
      safe: 'x'.repeat(120),
    });
    expect(output[0]).not.toContain('ignored');
  });

  it('records failure without exporting the error value', async () => {
    const output: string[] = [];
    vi.spyOn(console, 'log').mockImplementation((line) => output.push(String(line)));
    const secret = 'SECRET_FAILURE_VALUE';

    const result = await Effect.runPromise(
      Effect.gen(function* () {
        const observability = yield* Observability;
        return yield* observability.track('app.failure', Effect.fail(secret)).pipe(Effect.either);
      }).pipe(Effect.provide(makeObservabilityLayer())),
    );

    expect(result._tag).toBe('Left');
    expect(JSON.parse(output[0])).toMatchObject({
      operation: 'app.failure',
      outcome: 'error',
    });
    expect(output[0]).not.toContain(secret);
  });

  it('emits bounded AI records without prompts, arguments, or outputs', async () => {
    const output: string[] = [];
    vi.spyOn(console, 'log').mockImplementation((line) => output.push(String(line)));
    const secret = 'SECRET_PROMPT_CODE_AND_OUTPUT';

    await Effect.runPromise(
      Effect.gen(function* () {
        const aiTelemetry = yield* AiTelemetry;
        const telemetry = aiTelemetry.make();
        yield* Effect.promise(() =>
          Promise.resolve(
            telemetry.onLanguageModelCallEnd?.({
              provider: 'openai',
              modelId: 'gpt-test',
              finishReason: 'stop',
              usage: { inputTokens: 2, outputTokens: 3, totalTokens: 5 },
              performance: { responseTimeMs: 12, timeToFirstOutputMs: 4 },
              content: [secret],
            } as never),
          ),
        );
        yield* Effect.promise(() =>
          Promise.resolve(
            telemetry.onToolExecutionEnd?.({
              toolCall: { toolName: 'run_python', input: secret },
              toolExecutionMs: 8,
              toolOutput: { type: 'tool-result', output: secret },
            } as never),
          ),
        );
      }).pipe(Effect.provide(testLayer())),
    );

    expect(output.map((line) => JSON.parse(line).operation)).toEqual([
      'ai.model.call',
      'ai.tool.execute',
    ]);
    expect(output.join('\n')).not.toContain(secret);
  });
});
