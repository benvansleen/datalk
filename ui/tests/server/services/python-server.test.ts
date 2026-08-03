import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { NodeSdk } from '@effect/opentelemetry';
import { SpanKind } from '@opentelemetry/api';
import { InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { Cause, Effect, Exit, Layer, Option } from 'effect';
import { PythonServer } from '$lib/server/services/PythonServer';
import { PythonServerError } from '$lib/server/errors';
import { resetConfigEnv, stubConfigEnv } from '../../helpers/config-env';

describe('PythonServer service', () => {
  beforeEach(() => {
    stubConfigEnv();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    resetConfigEnv();
    vi.clearAllMocks();
  });

  it('creates an environment with the configured base URL', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: vi.fn().mockResolvedValue({ available_dataframes: 'df1, df2' }),
    });

    vi.stubGlobal('fetch', fetchMock);

    const program = Effect.gen(function* () {
      const server = yield* PythonServer;
      return yield* server.createEnvironment('chat-123', 'dataset-a');
    });

    const result = await Effect.runPromise(program.pipe(Effect.provide(PythonServer.Default)));

    expect(result.available_dataframes).toBe('df1, df2');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://localhost:8000/environment/create',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ chat_id: 'chat-123', dataset: 'dataset-a' }),
        headers: expect.any(Headers),
      }),
    );
    const headers = fetchMock.mock.calls[0][1].headers as Headers;
    expect(headers.get('content-type')).toBe('application/json');
    expect(headers.get('traceparent')).toMatch(/^00-[0-9a-f]{32}-[0-9a-f]{16}-01$/);
  });

  it('fails when the server returns a non-ok response', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      text: vi.fn().mockResolvedValue('nope'),
    });

    vi.stubGlobal('fetch', fetchMock);

    const program = Effect.gen(function* () {
      const server = yield* PythonServer;
      return yield* server.execute('chat-123', ['print(1)'], 'python');
    });

    const exit = await Effect.runPromiseExit(program.pipe(Effect.provide(PythonServer.Default)));

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        expect(failure.value).toBeInstanceOf(PythonServerError);
      }
    }
  });

  it('executes SQL requests with correct payload', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: vi.fn().mockResolvedValue({ outputs: 'ok' }),
    });

    vi.stubGlobal('fetch', fetchMock);

    const program = Effect.gen(function* () {
      const server = yield* PythonServer;
      return yield* server.execute('chat-999', ['select 1'], 'sql');
    });

    const result = await Effect.runPromise(program.pipe(Effect.provide(PythonServer.Default)));

    expect(result.outputs).toBe('ok');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://localhost:8000/execute',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          chat_id: 'chat-999',
          code: ['select 1'],
          language: 'sql',
        }),
        headers: expect.any(Headers),
      }),
    );
  });

  it('lists datasets and checks environment existence', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce({ status: 200, json: vi.fn().mockResolvedValue(['a', 'b']) })
      .mockResolvedValueOnce({ status: 200, json: vi.fn().mockResolvedValue(true) });

    vi.stubGlobal('fetch', fetchMock);

    const program = Effect.gen(function* () {
      const server = yield* PythonServer;
      const datasets = yield* server.listDatasets;
      const exists = yield* server.environmentExists('chat-1');
      return { datasets, exists };
    });

    const result = await Effect.runPromise(program.pipe(Effect.provide(PythonServer.Default)));

    expect(result.datasets).toEqual(['a', 'b']);
    expect(result.exists).toBe(true);
    expect(fetchMock).toHaveBeenCalledWith(
      'http://localhost:8000/dataset/list',
      expect.objectContaining({ headers: expect.any(Headers) }),
    );
    expect(fetchMock).toHaveBeenCalledWith(
      'http://localhost:8000/environment/exists?chat_id=chat-1',
      expect.objectContaining({ headers: expect.any(Headers) }),
    );
  });

  it('surfaces schema errors on malformed responses', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: vi.fn().mockResolvedValue({ wrong: 'shape' }),
    });

    vi.stubGlobal('fetch', fetchMock);

    const program = Effect.gen(function* () {
      const server = yield* PythonServer;
      return yield* server.createEnvironment('chat-123', 'dataset-a');
    });

    const exit = await Effect.runPromiseExit(program.pipe(Effect.provide(PythonServer.Default)));

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        expect(failure.value).toBeInstanceOf(PythonServerError);
      }
    }
  });

  it('exports client spans with trace context and response status but no payloads', async () => {
    const exporter = new InMemorySpanExporter();
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 202,
      json: vi.fn().mockResolvedValue({ outputs: 'ok' }),
    });
    vi.stubGlobal('fetch', fetchMock);

    const program = Effect.gen(function* () {
      const server = yield* PythonServer;
      yield* server.execute('chat-secret', ['print("secret")'], 'python');
      return exporter.getFinishedSpans();
    }).pipe(Effect.withSpan('test request', { kind: 'server' }));

    const spans = await Effect.runPromise(
      program.pipe(
        Effect.provide(
          Layer.merge(
            PythonServer.Default,
            NodeSdk.layer(() => ({
              resource: { serviceName: 'python-server-test' },
              spanProcessor: new SimpleSpanProcessor(exporter),
            })),
          ),
        ),
      ),
    );

    const clientSpan = spans.find((span) => span.name === 'HTTP POST /execute');
    expect(clientSpan?.kind).toBe(SpanKind.CLIENT);
    expect(clientSpan?.attributes).toMatchObject({
      'http.request.method': 'POST',
      'http.route': '/execute',
      'http.response.status_code': 202,
    });
    expect(JSON.stringify(clientSpan?.attributes)).not.toContain('secret');

    const headers = fetchMock.mock.calls[0][1].headers as Headers;
    expect(headers.get('traceparent')).toContain(clientSpan?.spanContext().traceId);
  });
});
