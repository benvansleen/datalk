import { Effect, Schema } from 'effect';
import { HttpError } from '../types';

export class Http extends Effect.Service<Http>()('app/Http', {
  sync: () => {
    const decodeJson = <A, I>(request: Request, schema: Schema.Schema<A, I>) =>
      Effect.tryPromise({
        try: () => request.json(),
        catch: () => new HttpError({ status: 400, message: 'Request body must be valid JSON' }),
      }).pipe(
        Effect.flatMap(Schema.decodeUnknown(schema)),
        Effect.catchTag('ParseError', (error) =>
          Effect.fail(
            new HttpError({ status: 400, message: `Invalid request body: ${String(error)}` }),
          ),
        ),
      );

    return {
      decodeJson,
    } as const;
  },
}) {}

export const HttpLive = Http.Default;
