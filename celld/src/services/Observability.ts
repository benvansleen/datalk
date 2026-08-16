import { Effect, Layer } from 'effect';

type AttributeValue = string | number | boolean | undefined;
export type ApplicationAttributes = Record<string, AttributeValue>;
export type ApplicationOutcome = 'success' | 'error' | 'cancelled';

const sanitize = (attributes: ApplicationAttributes): Record<string, string | number | boolean> => {
  const sanitized: Record<string, string | number | boolean> = {};
  for (const [key, value] of Object.entries(attributes)) {
    if (typeof value === 'string') sanitized[key] = value.slice(0, 120);
    else if (typeof value === 'number' && Number.isFinite(value)) sanitized[key] = value;
    else if (typeof value === 'boolean') sanitized[key] = value;
  }
  return sanitized;
};

const makeService = () => {
  const emit = (
    operation: string,
    outcome: ApplicationOutcome,
    attributes: ApplicationAttributes = {},
  ): void => {
    console.log(
      JSON.stringify({
        telemetry: 'application',
        operation,
        outcome,
        ...sanitize(attributes),
      }),
    );
  };

  const track = <A, E, R>(
    operation: string,
    effect: Effect.Effect<A, E, R>,
    attributes: ApplicationAttributes | (() => ApplicationAttributes) = {},
  ): Effect.Effect<A, E, R> =>
    Effect.suspend(() => {
      const startedAt = performance.now();
      const finish = (outcome: ApplicationOutcome) =>
        Effect.sync(() => {
          const values = typeof attributes === 'function' ? attributes() : attributes;
          emit(operation, outcome, {
            ...values,
            duration_ms: Math.max(0, performance.now() - startedAt),
          });
        });
      return effect.pipe(
        Effect.tapBoth({
          onFailure: () => finish('error'),
          onSuccess: () => finish('success'),
        }),
      );
    });

  return { emit, track } as const;
};

export class Observability extends Effect.Service<Observability>()('app/Observability', {
  sync: makeService,
}) {}

export const ObservabilityLive = Observability.Default;

export const makeObservabilityLayer = (): Layer.Layer<Observability> =>
  Layer.succeed(Observability, new Observability(makeService()));
