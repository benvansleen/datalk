import { Effect, Option } from 'effect';
import { describe, expect, it } from 'vitest';
import { requestSpanFromRequest, withRequestSpan } from '$lib/server/runtime';

const traceId = '4bf92f3577b34da6a3ce929d0e0e4736';
const parentSpanId = '00f067aa0ba902b7';

describe('server request tracing', () => {
  it('continues a sampled W3C trace and preserves tracestate', async () => {
    const request = new Request('http://datalk/api/internal/cells/project', {
      headers: {
        traceparent: `00-${traceId}-${parentSpanId}-01`,
        tracestate: 'vendor=value',
      },
    });
    const requestSpan = requestSpanFromRequest(
      request,
      new URL(request.url),
      '/api/internal/cells/project',
    );

    expect(requestSpan.parent).toMatchObject({
      traceId,
      spanId: parentSpanId,
      traceFlags: 1,
      isRemote: true,
    });
    expect(requestSpan.parent?.traceState?.serialize()).toBe('vendor=value');

    const span = await Effect.runPromise(withRequestSpan(Effect.currentSpan, requestSpan));
    expect(span.traceId).toBe(traceId);
    expect(span.spanId).not.toBe(parentSpanId);
    expect(Option.getOrThrow(span.parent)).toMatchObject({
      traceId,
      spanId: parentSpanId,
      sampled: true,
    });
  });

  it('preserves an unsampled parent', async () => {
    const request = new Request('http://datalk/api/internal/auth/verify-session', {
      headers: { traceparent: `00-${traceId}-${parentSpanId}-00` },
    });
    const requestSpan = requestSpanFromRequest(request, new URL(request.url));

    expect(requestSpan.parent?.traceFlags).toBe(0);
    const span = await Effect.runPromise(withRequestSpan(Effect.currentSpan, requestSpan));
    expect(Option.getOrThrow(span.parent)).toMatchObject({
      traceId,
      spanId: parentSpanId,
      sampled: false,
    });
  });

  it.each([
    undefined,
    'malformed',
    `00-${'0'.repeat(32)}-${parentSpanId}-01`,
    `00-${traceId}-${'0'.repeat(16)}-01`,
  ])('ignores a missing or invalid traceparent: %s', (traceparent) => {
    const headers = traceparent ? { traceparent } : undefined;
    const request = new Request('http://datalk/api/internal/cells/project', { headers });
    expect(requestSpanFromRequest(request, new URL(request.url)).parent).toBeUndefined();
  });
});
