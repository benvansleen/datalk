import { Effect, Layer, Schema } from 'effect';
import { Tool, Toolkit } from '@effect/ai';
import { ChatContext } from './ChatContext';
import { PythonServer } from './PythonServer';

// ============================================================================
// Tool Definitions
// ============================================================================

/**
 * Tool to check the available dataframes in the compute environment.
 * This is typically called first to understand what data is available.
 */
export const CheckEnvironment = Tool.make('check_environment', {
  description: 'Fetch the available dataframes within the given compute environment',
  success: Schema.String,
  failure: Schema.Never,
  parameters: {},
});

/**
 * Tool to execute Python code in the compute environment.
 * Returns stdout, stderr, and any exceptions from execution.
 */
export const RunPython = Tool.make('run_python', {
  description:
    'Provide lines of python code to be executed by a python interpreter. The results of stdout, stderr, & possible exceptions will be returned to you',
  success: Schema.String,
  failure: Schema.Never,
  parameters: {
    python_code: Schema.Array(Schema.String).annotations({
      description: 'Lines of Python code to execute',
    }),
  },
});

/**
 * Tool to execute SQL statements in the DuckDB environment.
 * Results are stored in a Pandas DataFrame called `sql_output`.
 */
export const RunSql = Tool.make('run_sql', {
  description:
    'Provide SQL statement to be executed within a Jupyter kernel. The result of the SQL expression will be stored in a Pandas DataFrame called `sql_output`. You can interact with this result via the `run_python` tool. Since you are running within a `duckdb` environment, you can access available dataframes within your SQL statement. Example: `SELECT * FROM df`',
  success: Schema.String,
  failure: Schema.Never,
  parameters: {
    sql_statement: Schema.Array(Schema.String).annotations({
      description: 'SQL statement lines to execute',
    }),
  },
});

// ============================================================================
// Toolkit
// ============================================================================

/**
 * The Datalk toolkit containing all available tools for the agent.
 */
export const DatalkToolkit = Toolkit.make(CheckEnvironment, RunPython, RunSql);

/**
 * Type for the tools in the Datalk toolkit.
 */
export type DatalkTools = Toolkit.Tools<typeof DatalkToolkit>;

// ============================================================================
// Tool Handlers Layer
// ============================================================================

/**
 * Layer that provides implementations for all Datalk tools.
 * Requires ChatContext for the current chat's ID and dataset,
 * and PythonServer for executing code in the compute environment.
 */
export const DatalkToolHandlersLive = DatalkToolkit.toLayer(
  Effect.gen(function* () {
    const pythonServer = yield* PythonServer;
    const ctx = yield* ChatContext;

    return {
      check_environment: () =>
        pythonServer
          .createEnvironment(ctx.chatId, ctx.dataset)
          .pipe(
            Effect.map((r) => r.available_dataframes),
            Effect.orDie,
          ),

      run_python: ({ python_code }) =>
        pythonServer.createEnvironment(ctx.chatId, ctx.dataset).pipe(
          Effect.flatMap(() => pythonServer.execute(ctx.chatId, [...python_code], 'python')),
          Effect.map((r) => JSON.stringify(r)),
          Effect.orDie,
        ),

      run_sql: ({ sql_statement }) =>
        pythonServer.createEnvironment(ctx.chatId, ctx.dataset).pipe(
          Effect.flatMap(() => pythonServer.execute(ctx.chatId, [...sql_statement], 'sql')),
          Effect.map((r) => JSON.stringify(r)),
          Effect.orDie,
        ),
    };
  }),
);

/**
 * Creates a tool handlers layer for a specific chat context.
 * This is used when running the agent to provide the correct context.
 * Requires PythonServer to be provided.
 */
export const makeDatalkToolHandlers = (chatId: string, dataset: string) =>
  DatalkToolHandlersLive.pipe(
    Layer.provide(Layer.succeed(ChatContext, { chatId, dataset })),
    Layer.provide(PythonServer.Default),
  );
