import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, describe, it } from 'node:test';
import { Data, Effect, Schedule } from 'effect';

const baseUrl = (process.env.DATALK_SERVER_URL ?? 'http://localhost:8000').replace(/\/$/, '');
const runSlowTests = process.env.RUN_SLOW_CONTRACT_TESTS === '1';
const dataset = 'College Football 2025';
const liveChatIds = new Set();

interface HttpResponse {
  readonly status: number;
  readonly contentType: string | null;
  readonly allow: string | null;
  readonly body: string;
}

interface ExecuteRequest {
  readonly chat_id: string;
  readonly code: string[];
  readonly language: 'python' | 'sql';
}

class HttpTransportError extends Data.TaggedError('HttpTransportError')<{
  readonly path: string;
  readonly message: string;
  readonly cause: unknown;
}> {}

const availableDataframes = `[('cfbd_2025_games', Index(['id', 'season', 'week', 'seasonType', 'startDate', 'startTimeTBD',
       'completed', 'neutralSite', 'conferenceGame', 'attendance', 'venueId',
       'venue', 'homeId', 'homeTeam', 'homeClassification', 'homeConference',
       'homePoints', 'homeLineScores', 'homePostgameWinProbability',
       'homePregameElo', 'homePostgameElo', 'awayId', 'awayTeam',
       'awayClassification', 'awayConference', 'awayPoints', 'awayLineScores',
       'awayPostgameWinProbability', 'awayPregameElo', 'awayPostgameElo',
       'excitementIndex', 'highlights', 'notes'],
      dtype='str'), (3736, 33)), ('cfbd_2025_lines', Index(['id', 'season', 'seasonType', 'week', 'startDate', 'homeTeamId',
       'homeTeam', 'homeConference', 'homeClassification', 'homeScore',
       'awayTeamId', 'awayTeam', 'awayConference', 'awayClassification',
       'awayScore', 'lines'],
      dtype='str'), (1524, 16))]
`;

const jsonHeaders = { 'Content-Type': 'application/json' };

function newChatId(label: string): string {
  const chatId = `contract-${label}-${randomUUID()}`;
  liveChatIds.add(chatId);
  return chatId;
}

function describeError(error: unknown): string {
  if (!(error instanceof Error)) return String(error);
  if (!(error.cause instanceof Error)) return `${error.name}: ${error.message}`;
  return `${error.name}: ${error.message}; caused by ${error.cause.name}: ${error.cause.message}`;
}

function request(
  path: string,
  init?: RequestInit,
): Effect.Effect<HttpResponse, HttpTransportError> {
  return Effect.tryPromise({
    try: async () => {
      const headers = new Headers(init?.headers);
      headers.set('Connection', 'close');
      const response = await fetch(`${baseUrl}${path}`, { ...init, headers });
      return {
        status: response.status,
        contentType: response.headers.get('content-type'),
        allow: response.headers.get('allow'),
        body: await response.text(),
      };
    },
    catch: (cause) =>
      new HttpTransportError({
        path,
        message: `Request to ${path} failed: ${describeError(cause)}`,
        cause,
      }),
  });
}

function idempotentRequest(
  path: string,
  init?: RequestInit,
): Effect.Effect<HttpResponse, HttpTransportError> {
  return request(path, init).pipe(Effect.retry(Schedule.recurs(1)));
}

function post(path: string, body: unknown): Effect.Effect<HttpResponse, HttpTransportError> {
  return request(path, {
    method: 'POST',
    headers: jsonHeaders,
    body: JSON.stringify(body),
  });
}

function idempotentPost(
  path: string,
  body: unknown,
): Effect.Effect<HttpResponse, HttpTransportError> {
  return idempotentRequest(path, {
    method: 'POST',
    headers: jsonHeaders,
    body: JSON.stringify(body),
  });
}

function assertJsonResponse(response: HttpResponse, status: number, body: unknown): void {
  assert.equal(response.status, status);
  assert.equal(response.contentType, 'application/json');
  assert.equal(response.body, JSON.stringify(body));
}

function environmentExists(chatId: string): Effect.Effect<HttpResponse, HttpTransportError> {
  return idempotentRequest(`/environment/exists?chat_id=${encodeURIComponent(chatId)}`);
}

function createEnvironment(
  chatId: string,
  selectedDataset = dataset,
): Effect.Effect<HttpResponse, HttpTransportError> {
  return idempotentPost('/environment/create', { chat_id: chatId, dataset: selectedDataset });
}

function execute(
  chatId: string,
  code: string[],
  language: ExecuteRequest['language'] = 'python',
): Effect.Effect<HttpResponse, HttpTransportError> {
  const request: ExecuteRequest = { chat_id: chatId, code, language };
  return post('/execute', request);
}

function destroyEnvironment(chatId: string): Effect.Effect<HttpResponse, HttpTransportError> {
  return idempotentPost('/environment/destroy', { chat_id: chatId }).pipe(
    Effect.tap((response) =>
      Effect.sync(() => {
        if (response.status === 200) liveChatIds.delete(chatId);
      }),
    ),
  );
}

after(() =>
  Effect.runPromise(
    Effect.forEach(
      liveChatIds,
      (chatId) => idempotentPost('/environment/destroy', { chat_id: chatId }).pipe(Effect.ignore),
      {
        concurrency: 1,
        discard: true,
      },
    ).pipe(Effect.ensuring(Effect.sync(() => liveChatIds.clear()))),
  ),
);

describe('Datalk execution server HTTP contract', () => {
  it('lists the configured datasets', () =>
    Effect.runPromise(
      Effect.gen(function* () {
        assertJsonResponse(yield* idempotentRequest('/dataset/list'), 200, [dataset]);
      }),
    ));

  it('uses the declared HTTP methods', () =>
    Effect.runPromise(
      Effect.gen(function* () {
        const response = yield* request('/execute');

        assertJsonResponse(response, 405, { detail: 'Method Not Allowed' });
        assert.equal(response.allow, 'POST');
      }),
    ));

  it('returns the current request-validation errors', () =>
    Effect.runPromise(
      Effect.gen(function* () {
        assertJsonResponse(yield* request('/environment/exists'), 422, {
          detail: [
            {
              type: 'missing',
              loc: ['query', 'chat_id'],
              msg: 'Field required',
              input: null,
            },
          ],
        });

        assertJsonResponse(
          yield* request('/execute', { method: 'POST', headers: jsonHeaders }),
          422,
          {
            detail: [
              {
                type: 'missing',
                loc: ['body'],
                msg: 'Field required',
                input: null,
              },
            ],
          },
        );

        assertJsonResponse(
          yield* post('/execute', { chat_id: 'validation', code: 'print(1)', language: 'python' }),
          422,
          {
            detail: [
              {
                type: 'list_type',
                loc: ['body', 'code'],
                msg: 'Input should be a valid list',
                input: 'print(1)',
              },
            ],
          },
        );

        assertJsonResponse(yield* post('/environment/create', { chat_id: 'validation' }), 422, {
          detail: [
            {
              type: 'missing',
              loc: ['body', 'dataset'],
              msg: 'Field required',
              input: { chat_id: 'validation' },
            },
          ],
        });

        assertJsonResponse(yield* post('/environment/destroy', {}), 422, {
          detail: [
            {
              type: 'missing',
              loc: ['body', 'chat_id'],
              msg: 'Field required',
              input: {},
            },
          ],
        });

        assertJsonResponse(
          yield* post('/execute', {
            chat_id: 'validation',
            code: ['console.log(1)'],
            language: 'javascript',
          }),
          422,
          {
            detail: [
              {
                type: 'literal_error',
                loc: ['body', 'language', "literal['python']"],
                msg: "Input should be 'python'",
                input: 'javascript',
                ctx: { expected: "'python'" },
              },
              {
                type: 'literal_error',
                loc: ['body', 'language', "literal['sql']"],
                msg: "Input should be 'sql'",
                input: 'javascript',
                ctx: { expected: "'sql'" },
              },
            ],
          },
        );

        assertJsonResponse(
          yield* request('/execute', {
            method: 'POST',
            headers: jsonHeaders,
            body: '{',
          }),
          422,
          {
            detail: [
              {
                type: 'json_invalid',
                loc: ['body', 1],
                msg: 'JSON decode error',
                input: {},
                ctx: { error: 'Expecting property name enclosed in double quotes' },
              },
            ],
          },
        );
      }),
    ));

  it('rejects an unknown dataset without creating an environment', () =>
    Effect.runPromise(
      Effect.gen(function* () {
        const chatId = newChatId('unknown-dataset');

        assertJsonResponse(yield* createEnvironment(chatId, 'missing-dataset'), 404, {
          detail: 'Unknown dataset: missing-dataset',
        });
        assertJsonResponse(yield* environmentExists(chatId), 200, false);
        assertJsonResponse(yield* destroyEnvironment(chatId), 200, null);
      }),
    ));

  it('preserves lifecycle, execution, persistence, and isolation behavior', () =>
    Effect.runPromise(
      Effect.gen(function* () {
        const chatId = newChatId('lifecycle with spaces');
        const isolatedChatId = newChatId('isolated');

        assertJsonResponse(yield* environmentExists(chatId), 200, false);
        assertJsonResponse(yield* execute(chatId, ['print(1)']), 400, {
          detail: `Execution environment not yet created for ${chatId}`,
        });
        assertJsonResponse(yield* destroyEnvironment(chatId), 200, null);
        liveChatIds.add(chatId);

        assertJsonResponse(yield* createEnvironment(chatId), 200, {
          available_dataframes: availableDataframes,
        });
        assertJsonResponse(yield* environmentExists(chatId), 200, true);

        assertJsonResponse(yield* execute(chatId, ['contract_value = 41']), 200, { outputs: '' });
        assertJsonResponse(yield* createEnvironment(chatId), 200, {
          available_dataframes: availableDataframes,
        });
        assertJsonResponse(
          yield* execute(chatId, ['joined_value = contract_value', 'print(joined_value + 1)']),
          200,
          { outputs: '42\n' },
        );
        assertJsonResponse(
          yield* execute(chatId, ['import sys', 'print("contract-stderr", file=sys.stderr)']),
          200,
          { outputs: 'contract-stderr\n' },
        );
        assertJsonResponse(yield* execute(chatId, ['40 + 2']), 200, { outputs: '' });
        assertJsonResponse(yield* execute(chatId, ['raise RuntimeError("contract-boom")']), 200, {
          outputs: 'Error executing code: contract-boom',
        });
        assertJsonResponse(
          yield* execute(chatId, ['print(cfbd_2025_games.shape)', 'print(cfbd_2025_lines.shape)']),
          200,
          { outputs: '(3736, 33)\n(1524, 16)\n' },
        );
        const tables = yield* execute(chatId, ['SHOW TABLES'], 'sql');
        assert.equal(tables.status, 200);
        const tablesOutput: unknown = JSON.parse(tables.body).outputs;
        assert.ok(typeof tablesOutput === 'string');
        assert.match(tablesOutput, /cfbd_2025_games/);
        assert.match(tablesOutput, /cfbd_2025_lines/);

        assertJsonResponse(
          yield* execute(chatId, ['SELECT COUNT(*) AS game_count FROM cfbd_2025_games'], 'sql'),
          200,
          { outputs: '   game_count\n0        3736\n' },
        );
        assertJsonResponse(
          yield* execute(chatId, ['print(int(sql_output.loc[0, "game_count"]))']),
          200,
          { outputs: '3736\n' },
        );
        const invalidSql = yield* execute(chatId, ['SELEC 1'], 'sql');
        assert.equal(invalidSql.status, 200);
        assert.equal(invalidSql.contentType, 'application/json');
        const invalidSqlOutput: unknown = JSON.parse(invalidSql.body).outputs;
        assert.ok(typeof invalidSqlOutput === 'string');
        assert.equal(
          invalidSqlOutput.replace(/\s+/g, ' ').trim(),
          'Error executing code: Parser Error: syntax error at or near "SELEC" LINE 1: SELEC 1 ^',
        );

        const multilineSql = yield* execute(
          chatId,
          ['SELECT COUNT(*) AS game_count', 'FROM cfbd_2025_games'],
          'sql',
        );
        assert.equal(multilineSql.status, 200);
        assert.equal(multilineSql.contentType, 'application/json');
        const multilineSqlOutput: unknown = JSON.parse(multilineSql.body).outputs;
        assert.equal(multilineSqlOutput, '   game_count\n0        3736\n');

        assertJsonResponse(yield* createEnvironment(isolatedChatId), 200, {
          available_dataframes: availableDataframes,
        });
        assertJsonResponse(
          yield* execute(isolatedChatId, ['print("contract_value" in globals())']),
          200,
          { outputs: 'False\n' },
        );

        assertJsonResponse(yield* destroyEnvironment(chatId), 200, null);
        assertJsonResponse(yield* environmentExists(chatId), 200, false);
        assertJsonResponse(yield* execute(chatId, ['print(1)']), 400, {
          detail: `Execution environment not yet created for ${chatId}`,
        });

        liveChatIds.add(chatId);
        assertJsonResponse(yield* createEnvironment(chatId), 200, {
          available_dataframes: availableDataframes,
        });
        assertJsonResponse(yield* execute(chatId, ['print("contract_value" in globals())']), 200, {
          outputs: 'False\n',
        });

        assertJsonResponse(yield* destroyEnvironment(chatId), 200, null);
        assertJsonResponse(yield* destroyEnvironment(isolatedChatId), 200, null);
        assertJsonResponse(yield* destroyEnvironment(isolatedChatId), 200, null);
      }),
    ));

  it(
    'returns the current execution timeout response',
    { skip: !runSlowTests, timeout: 140_000 },
    () =>
      Effect.runPromise(
        Effect.gen(function* () {
          const chatId = newChatId('timeout');

          assertJsonResponse(yield* createEnvironment(chatId), 200, {
            available_dataframes: availableDataframes,
          });
          assertJsonResponse(yield* execute(chatId, ['import time', 'time.sleep(121)']), 400, {
            detail: 'Code execution timed out',
          });
          assertJsonResponse(yield* destroyEnvironment(chatId), 200, null);
        }),
      ),
  );
});
