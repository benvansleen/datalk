import { describe, expect, it } from 'vitest';
import { transitionGeneration, type GenerationState } from '../src/cell/shared';

describe('generation state machine', () => {
  it('moves a submitted request through claim, renewal, and completion', () => {
    const pending = transitionGeneration(
      { status: 'idle' },
      {
        type: 'submit',
        requestId: 'request-1',
      },
    );
    const running = transitionGeneration(pending!, {
      type: 'claim',
      leaseId: 'lease-1',
      leaseExpiresAt: 200,
      now: 100,
    });
    const renewed = transitionGeneration(running!, {
      type: 'renew',
      leaseId: 'lease-1',
      leaseExpiresAt: 300,
      now: 150,
    });
    const completed = transitionGeneration(renewed!, {
      type: 'complete',
      leaseId: 'lease-1',
      now: 250,
    });

    expect(pending).toEqual({ status: 'pending', requestId: 'request-1' });
    expect(running).toEqual({
      status: 'running',
      requestId: 'request-1',
      leaseId: 'lease-1',
      leaseExpiresAt: 200,
    });
    expect(renewed).toEqual({ ...running, leaseExpiresAt: 300 });
    expect(completed).toEqual({ status: 'idle' });
  });

  it('rejects invalid and stale-owner transitions', () => {
    const running: GenerationState = {
      status: 'running',
      requestId: 'request-1',
      leaseId: 'lease-1',
      leaseExpiresAt: 200,
    };

    expect(transitionGeneration(running, { type: 'submit', requestId: 'request-2' })).toBeNull();
    expect(
      transitionGeneration(running, {
        type: 'claim',
        leaseId: 'lease-2',
        leaseExpiresAt: 300,
        now: 199,
      }),
    ).toBeNull();
    expect(
      transitionGeneration(running, {
        type: 'renew',
        leaseId: 'lease-2',
        leaseExpiresAt: 300,
        now: 150,
      }),
    ).toBeNull();
    expect(
      transitionGeneration(running, { type: 'complete', leaseId: 'lease-2', now: 150 }),
    ).toBeNull();
  });

  it('rejects renewal and completion after lease expiry', () => {
    const running: GenerationState = {
      status: 'running',
      requestId: 'request-1',
      leaseId: 'lease-1',
      leaseExpiresAt: 200,
    };

    expect(
      transitionGeneration(running, {
        type: 'renew',
        leaseId: 'lease-1',
        leaseExpiresAt: 300,
        now: 200,
      }),
    ).toBeNull();
    expect(
      transitionGeneration(running, { type: 'complete', leaseId: 'lease-1', now: 200 }),
    ).toBeNull();
  });

  it('allows an expired running request to be reclaimed', () => {
    const reclaimed = transitionGeneration(
      {
        status: 'running',
        requestId: 'request-1',
        leaseId: 'expired-lease',
        leaseExpiresAt: 200,
      },
      {
        type: 'claim',
        leaseId: 'new-lease',
        leaseExpiresAt: 300,
        now: 200,
      },
    );

    expect(reclaimed).toEqual({
      status: 'running',
      requestId: 'request-1',
      leaseId: 'new-lease',
      leaseExpiresAt: 300,
    });
  });
});
