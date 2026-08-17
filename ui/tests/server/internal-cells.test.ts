import { Effect, Schema } from 'effect';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { resetConfigEnv, stubConfigEnv } from '../helpers/config-env';

const mocks = vi.hoisted(() => {
  const transaction = Object.assign(vi.fn(), { json: vi.fn((value: unknown) => value) });
  const sql = Object.assign(vi.fn(), {
    begin: vi.fn((callback) => callback(transaction)),
    end: vi.fn().mockResolvedValue(undefined),
  });
  return { sql, transaction };
});

vi.mock('postgres', () => ({ default: vi.fn(() => mocks.sql) }));

import { Config } from '$lib/server/services/Config';
import {
  internalSignature,
  projectCellEvents,
  verifyInternalCellRequest,
  ProjectionRequest,
  type ProjectionRequest as ProjectionRequestType,
} from '$lib/server/internal-cells';

type QueryCall = { query: string; values: unknown[] };

const snapshot = {
  id: '9e27a5f0-679d-4a90-9c55-49fb8a913e29',
  userId: 'user-1',
  dataset: 'cfbd',
  title: 'A chat',
  deleted: false,
  generating: false,
  currentMessageRequestId: null,
  createdAt: 0,
  updatedAt: 0,
  messages: [],
};

const request = (sequence: number): ProjectionRequestType => ({
  cellKind: 'chat',
  cellId: snapshot.id,
  events: [{ sequence, type: 'chat-snapshot', occurredAt: 0, snapshot }],
});

const provideConfig = <A, E>(effect: Effect.Effect<A, E, Config>) =>
  effect.pipe(Effect.provide(Config.Default));

const installTransaction = (lastSequence: number) => {
  const calls: QueryCall[] = [];
  let messageCounter = 0;
  mocks.transaction.mockImplementation(
    async (strings: TemplateStringsArray, ...values: unknown[]) => {
      const query = strings.join('?');
      calls.push({ query, values });
      if (query.includes('SELECT last_sequence')) return [{ last_sequence: lastSequence }];
      if (query.includes('RETURNING id')) return [{ id: `message-${(messageCounter += 1)}` }];
      return [];
    },
  );
  return calls;
};

const findCalls = (calls: QueryCall[], fragment: string) =>
  calls.filter((call) => call.query.includes(fragment));

describe('cell projection ledger', () => {
  beforeEach(() => {
    stubConfigEnv();
    mocks.transaction.mockReset();
    mocks.sql.begin.mockClear();
    mocks.sql.end.mockClear();
  });
  afterEach(resetConfigEnv);

  it('rebases a new ledger to an authoritative full snapshot', async () => {
    let initialSequence: number | undefined;
    mocks.transaction.mockImplementation(
      async (strings: TemplateStringsArray, ...values: unknown[]) => {
        const query = strings.join('');
        if (query.includes('INSERT INTO cell_projection_ledger')) {
          initialSequence = values[2] as number;
          return [];
        }
        if (query.includes('SELECT last_sequence')) return [{ last_sequence: initialSequence }];
        return [];
      },
    );

    await expect(Effect.runPromise(provideConfig(projectCellEvents(request(7))))).resolves.toEqual({
      acknowledgedSequence: 7,
    });
    expect(initialSequence).toBe(6);
  });

  it('continues to reject a gap for an existing ledger', async () => {
    mocks.transaction.mockImplementation(async (strings: TemplateStringsArray) => {
      if (strings.join('').includes('SELECT last_sequence')) return [{ last_sequence: 2 }];
      return [];
    });

    await expect(Effect.runPromise(provideConfig(projectCellEvents(request(4))))).rejects.toThrow(
      'Projection sequence gap',
    );
  });

  it('acknowledges already-applied events without writing anything', async () => {
    const calls = installTransaction(7);

    await expect(Effect.runPromise(provideConfig(projectCellEvents(request(7))))).resolves.toEqual({
      acknowledgedSequence: 7,
    });
    expect(findCalls(calls, 'INSERT INTO chat')).toEqual([]);
    expect(findCalls(calls, 'UPDATE cell_projection_ledger')).toEqual([]);
  });

  it('applies only pending events in sequence order and advances the ledger', async () => {
    const calls = installTransaction(3);
    const payload: ProjectionRequestType = {
      cellKind: 'chat',
      cellId: snapshot.id,
      events: [
        {
          sequence: 5,
          type: 'chat-snapshot',
          occurredAt: 0,
          snapshot: { ...snapshot, title: 'five' },
        },
        {
          sequence: 4,
          type: 'chat-snapshot',
          occurredAt: 0,
          snapshot: { ...snapshot, title: 'four' },
        },
      ],
    };

    await expect(Effect.runPromise(provideConfig(projectCellEvents(payload)))).resolves.toEqual({
      acknowledgedSequence: 5,
    });

    const upserts = findCalls(calls, 'INSERT INTO chat ');
    expect(upserts).toHaveLength(2);
    expect(upserts[0].values[6]).toBe('four');
    expect(upserts[1].values[6]).toBe('five');
    const [ledgerUpdate] = findCalls(calls, 'UPDATE cell_projection_ledger');
    expect(ledgerUpdate.values[0]).toBe(5);
  });

  it('rejects non-contiguous batches before touching the ledger', async () => {
    const calls = installTransaction(0);
    const payload: ProjectionRequestType = {
      cellKind: 'chat',
      cellId: snapshot.id,
      events: [
        { sequence: 4, type: 'chat-snapshot', occurredAt: 0, snapshot },
        { sequence: 6, type: 'chat-snapshot', occurredAt: 0, snapshot },
      ],
    };

    await expect(Effect.runPromise(provideConfig(projectCellEvents(payload)))).rejects.toThrow(
      'Projection batch must be contiguous',
    );
    expect(calls).toEqual([]);
  });

  it('upserts the chat and rewrites its messages from the snapshot', async () => {
    const calls = installTransaction(0);
    const fullSnapshot = {
      ...snapshot,
      createdAt: 1_700_000_000_000,
      updatedAt: 1_700_000_060_000,
      messages: [
        { id: 'm-1', role: 'user' as const, content: 'Hello', createdAt: 1_700_000_000_000 },
        { id: 'm-2', role: 'assistant' as const, content: 'Hi!', createdAt: 1_700_000_010_000 },
        {
          id: 'm-3',
          role: 'tool' as const,
          content: '',
          createdAt: 1_700_000_020_000,
          toolCallId: 'tc-1',
          toolName: 'run_sql',
          toolArguments: { sql_statement: ['select 1'] },
          toolResult: '1',
          toolFailed: false,
        },
        {
          id: 'm-4',
          role: 'tool' as const,
          content: '',
          createdAt: 1_700_000_030_000,
          toolCallId: 'tc-2',
          toolName: 'run_python',
          toolArguments: {},
          toolResult: 'done',
        },
      ],
    };

    await expect(
      Effect.runPromise(
        provideConfig(
          projectCellEvents({
            cellKind: 'chat',
            cellId: snapshot.id,
            events: [{ sequence: 1, type: 'chat-snapshot', occurredAt: 0, snapshot: fullSnapshot }],
          }),
        ),
      ),
    ).resolves.toEqual({ acknowledgedSequence: 1 });

    const [upsert] = findCalls(calls, 'INSERT INTO chat ');
    expect(upsert.values).toEqual([
      snapshot.id,
      'user-1',
      'cfbd',
      new Date(1_700_000_000_000),
      new Date(1_700_000_060_000),
      null,
      'A chat',
      null,
    ]);

    expect(findCalls(calls, 'DELETE FROM chat_message')).toHaveLength(1);

    const messageInserts = findCalls(calls, 'INSERT INTO chat_message ');
    expect(messageInserts.map((call) => [call.values[1], call.values[2]])).toEqual([
      ['user', 0],
      ['assistant', 1],
      ['tool', 2],
      ['tool', 3],
    ]);

    const parts = findCalls(calls, 'INSERT INTO chat_message_part');
    expect(parts.map((call) => [call.values[0], call.values[1]])).toEqual([
      ['message-1', 'text'],
      ['message-2', 'text'],
      ['message-3', 'tool-call'],
      ['message-3', 'tool-result'],
      ['message-4', 'tool-call'],
      ['message-4', 'tool-result'],
    ]);
    expect(parts[0].values[3]).toEqual({ text: 'Hello' });
    expect(parts[2].values[3]).toEqual({
      id: 'tc-1',
      name: 'run_sql',
      params: { sql_statement: ['select 1'] },
    });
    expect(parts[3].values[3]).toEqual({
      id: 'tc-1',
      name: 'run_sql',
      result: '1',
      isFailure: false,
    });
    expect(parts[5].values[3]).toEqual({
      id: 'tc-2',
      name: 'run_python',
      result: 'done',
      isFailure: false,
    });
  });

  it('marks deleted chats with a deleted_at timestamp', async () => {
    const calls = installTransaction(0);

    await expect(
      Effect.runPromise(
        provideConfig(
          projectCellEvents({
            cellKind: 'chat',
            cellId: snapshot.id,
            events: [
              {
                sequence: 1,
                type: 'chat-snapshot',
                occurredAt: 0,
                snapshot: { ...snapshot, deleted: true, updatedAt: 1_700_000_060_000 },
              },
            ],
          }),
        ),
      ),
    ).resolves.toEqual({ acknowledgedSequence: 1 });

    const [upsert] = findCalls(calls, 'INSERT INTO chat ');
    expect(upsert.values[7]).toEqual(new Date(1_700_000_060_000));
  });

  it('closes the database connection even when the projection fails', async () => {
    mocks.transaction.mockImplementation(async (strings: TemplateStringsArray) => {
      if (strings.join('').includes('SELECT last_sequence')) return [{ last_sequence: 2 }];
      return [];
    });

    await expect(Effect.runPromise(provideConfig(projectCellEvents(request(4))))).rejects.toThrow(
      'Projection sequence gap',
    );
    expect(mocks.sql.end).toHaveBeenCalledTimes(1);
  });
});

describe('projection request schema', () => {
  const validEvent = { sequence: 1, type: 'chat-snapshot', occurredAt: 0, snapshot };

  const decode = (input: unknown) => Schema.decodeUnknownEither(ProjectionRequest)(input);

  it('accepts a minimal valid payload', () => {
    expect(decode({ cellKind: 'chat', cellId: snapshot.id, events: [validEvent] })._tag).toBe(
      'Right',
    );
  });

  it('rejects empty and oversized batches', () => {
    expect(decode({ cellKind: 'chat', cellId: snapshot.id, events: [] })._tag).toBe('Left');
    expect(
      decode({
        cellKind: 'chat',
        cellId: snapshot.id,
        events: Array.from({ length: 101 }, (_, index) => ({ ...validEvent, sequence: index + 1 })),
      })._tag,
    ).toBe('Left');
  });

  it('rejects unknown cell kinds and event types', () => {
    expect(decode({ cellKind: 'user', cellId: snapshot.id, events: [validEvent] })._tag).toBe(
      'Left',
    );
    expect(
      decode({ cellKind: 'chat', cellId: snapshot.id, events: [{ ...validEvent, type: 'other' }] })
        ._tag,
    ).toBe('Left');
  });

  it('rejects non-positive sequences and malformed snapshots', () => {
    expect(
      decode({ cellKind: 'chat', cellId: snapshot.id, events: [{ ...validEvent, sequence: 0 }] })
        ._tag,
    ).toBe('Left');
    expect(
      decode({
        cellKind: 'chat',
        cellId: snapshot.id,
        events: [{ ...validEvent, snapshot: { ...snapshot, messages: 'nope' } }],
      })._tag,
    ).toBe('Left');
  });
});

describe('verifyInternalCellRequest', () => {
  const url = 'https://datalk.test/api/internal/cells/project';
  const body = '{"cellKind":"chat"}';

  const signedRequest = async (options: { secret?: string; timestamp?: string; body?: string }) => {
    const timestamp = options.timestamp ?? String(Date.now());
    const signature = await Effect.runPromise(
      internalSignature(
        options.secret ?? 'test-internal-projection-secret',
        'POST',
        '/api/internal/cells/project',
        options.body ?? body,
        timestamp,
      ),
    );
    return new Request(url, {
      method: 'POST',
      headers: {
        'x-datalk-internal-timestamp': timestamp,
        'x-datalk-internal-signature': signature,
      },
      body,
    });
  };

  const verify = (request: Request, payload: string) =>
    Effect.runPromise(provideConfig(verifyInternalCellRequest(request, payload)));

  beforeEach(stubConfigEnv);
  afterEach(resetConfigEnv);

  it('accepts a freshly signed request', async () => {
    await expect(verify(await signedRequest({}), body)).resolves.toBeUndefined();
  });

  it('rejects requests without signing headers', async () => {
    await expect(
      Effect.runPromiseExit(
        provideConfig(verifyInternalCellRequest(new Request(url, { method: 'POST' }), body)),
      ),
    ).resolves.toMatchObject({ _tag: 'Failure' });
  });

  it('rejects timestamps outside the clock skew window', async () => {
    const result = await Effect.runPromiseExit(
      provideConfig(
        verifyInternalCellRequest(
          await signedRequest({ timestamp: String(Date.now() - 60_000) }),
          body,
        ),
      ),
    );
    expect(result._tag).toBe('Failure');
  });

  it('rejects signatures made with the wrong secret or a tampered body', async () => {
    const wrongSecret = await Effect.runPromiseExit(
      provideConfig(
        verifyInternalCellRequest(await signedRequest({ secret: 'other-secret' }), body),
      ),
    );
    expect(wrongSecret._tag).toBe('Failure');

    const tamperedBody = await Effect.runPromiseExit(
      provideConfig(verifyInternalCellRequest(await signedRequest({}), '{"cellKind":"user"}')),
    );
    expect(tamperedBody._tag).toBe('Failure');
  });
});
