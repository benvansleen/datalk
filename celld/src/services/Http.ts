import { Effect, Schema } from 'effect';
import { HttpError } from '../types';

export class Http extends Effect.Service<Http>()('app/Http', {
  effect: Effect.gen(function* () {
    const decodeJson = <A, I>(request: Request, schema: Schema.Schema<A, I>) =>
      Effect.tryPromise({
        try: () => request.json(),
        catch: () => new HttpError({ status: 400, message: 'Request body must be valid JSON' }),
      }).pipe(
        Effect.flatMap(Schema.decodeUnknown(schema)),
        Effect.mapError((error) =>
          error instanceof HttpError
            ? error
            : new HttpError({ status: 400, message: `Invalid request body: ${String(error)}` }),
        ),
      );

    return {
      decodeJson,
    } as const;
  }),
}) {}

export const HttpLive = Http.Default;
