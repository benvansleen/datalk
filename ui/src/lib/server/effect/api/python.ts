import { Effect } from 'effect';
import { PythonServer } from '../services/PythonServer';

/**
 * List available datasets from the Python server
 */
export const listDatasets = Effect.gen(function* () {
  const pythonServer = yield* PythonServer;
  return yield* pythonServer.listDatasets;
}).pipe(Effect.withSpan('Python.listDatasets'));

/**
 * Create or get an execution environment for a chat
 */
export const createEnvironment = (chatId: string, dataset: string) =>
  Effect.gen(function* () {
    const pythonServer = yield* PythonServer;
    return yield* pythonServer.createEnvironment(chatId, dataset);
  }).pipe(Effect.withSpan('Python.createEnvironment', { attributes: { chatId, dataset } }));

/**
 * Execute Python code in a chat's environment
 */
export const executePython = (chatId: string, code: string[]) =>
  Effect.gen(function* () {
    const pythonServer = yield* PythonServer;
    return yield* pythonServer.execute(chatId, code, 'python');
  }).pipe(Effect.withSpan('Python.executePython', { attributes: { chatId } }));

/**
 * Execute SQL code in a chat's environment
 */
export const executeSql = (chatId: string, code: string[]) =>
  Effect.gen(function* () {
    const pythonServer = yield* PythonServer;
    return yield* pythonServer.execute(chatId, code, 'sql');
  }).pipe(Effect.withSpan('Python.executeSql', { attributes: { chatId } }));

/**
 * Destroy an execution environment
 */
export const destroyEnvironment = (chatId: string) =>
  Effect.gen(function* () {
    const pythonServer = yield* PythonServer;
    return yield* pythonServer.destroyEnvironment(chatId);
  }).pipe(Effect.withSpan('Python.destroyEnvironment', { attributes: { chatId } }));

/**
 * Check if an environment exists for a chat
 */
export const environmentExists = (chatId: string) =>
  Effect.gen(function* () {
    const pythonServer = yield* PythonServer;
    return yield* pythonServer.environmentExists(chatId);
  }).pipe(Effect.withSpan('Python.environmentExists', { attributes: { chatId } }));
