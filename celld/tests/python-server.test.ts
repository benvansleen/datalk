import { Effect } from 'effect';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { PythonServer } from '../src/services/PythonServer';
import type { Env } from '../src/types';
import { runWithEnv } from './helpers/runtime';

const env = { PYTHON_SERVER_URL: 'http://python-server:8000' } as Env;

describe('execution service client', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('uses the existing environment-create contract', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(Response.json({ available_dataframes: 'games, lines' }));
    vi.stubGlobal('fetch', fetchMock);

    await expect(
      runWithEnv(
        env,
        Effect.gen(function* () {
          const pythonServer = yield* PythonServer;
          return yield* pythonServer.createEnvironment('chat-1', 'cfbd');
        }),
      ),
    ).resolves.toEqual({ available_dataframes: 'games, lines' });
    expect(fetchMock).toHaveBeenCalledWith(
      new URL('http://python-server:8000/environment/create'),
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ chat_id: 'chat-1', dataset: 'cfbd' }),
      }),
    );
  });

  it('validates execution responses before returning them to a cell', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(Response.json({ unexpected: true })));

    await expect(
      runWithEnv(
        env,
        Effect.gen(function* () {
          const pythonServer = yield* PythonServer;
          return yield* pythonServer.execute('chat-1', ['select 1'], 'sql');
        }),
      ),
    ).rejects.toThrow('Invalid execution service response');
  });

  it('passes image attachments through and defaults them when absent', async () => {
    const attachment = { id: 'img-1', mime: 'image/png', data: 'aGVsbG8=' };
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(Response.json({ outputs: 'ok', images: [attachment], telemetry: [] }))
      .mockResolvedValueOnce(Response.json({ outputs: 'ok' }));
    vi.stubGlobal('fetch', fetchMock);

    await expect(
      runWithEnv(
        env,
        Effect.gen(function* () {
          const pythonServer = yield* PythonServer;
          return yield* pythonServer.execute('chat-1', ['print(1)'], 'python');
        }),
      ),
    ).resolves.toEqual({ outputs: 'ok', images: [attachment] });

    await expect(
      runWithEnv(
        env,
        Effect.gen(function* () {
          const pythonServer = yield* PythonServer;
          return yield* pythonServer.execute('chat-1', ['print(2)'], 'python');
        }),
      ),
    ).resolves.toEqual({ outputs: 'ok', images: [] });
  });
});
