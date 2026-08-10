import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { Effect, Layer } from 'effect';
import { Config } from '$lib/server/services/Config';
import { LiveSession } from '$lib/server/services/LiveSession';
import { resetConfigEnv, stubConfigEnv } from '../../helpers/config-env';

const decode = (value: string) =>
  JSON.parse(Buffer.from(value.replaceAll('-', '+').replaceAll('_', '/'), 'base64url').toString());

describe('LiveSession service', () => {
  beforeEach(stubConfigEnv);
  afterEach(resetConfigEnv);

  it('mints a five-minute JWT for the celld Worker', async () => {
    const result = await Effect.runPromise(
      Effect.gen(function* () {
        const liveSession = yield* LiveSession;
        return yield* liveSession.mint('user-1');
      }).pipe(Effect.provide(Layer.provide(LiveSession.Default, Config.Default))),
    );
    const [, encodedPayload] = result.token.split('.');
    const payload = decode(encodedPayload);

    expect(payload).toMatchObject({ sub: 'user-1', aud: 'datalk-live', iss: 'datalk' });
    expect(payload.exp - Math.floor(Date.now() / 1000)).toBeGreaterThanOrEqual(299);
    expect(payload.exp - Math.floor(Date.now() / 1000)).toBeLessThanOrEqual(300);
  });
});
