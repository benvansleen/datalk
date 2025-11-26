import { tool } from '@openai/agents';
import { z } from 'zod';

let python_server_url: string;
const getPythonServerUrl = () => {
  if (!python_server_url) {
    const { PYTHON_SERVER_HOST, PYTHON_SERVER_PORT } = process.env;
    python_server_url = `http://${PYTHON_SERVER_HOST}:${PYTHON_SERVER_PORT}`;
    console.log(`Using python_server_url: ${python_server_url}`);
  }
  return python_server_url;
};

export const checkEnvironmentTool = tool({
  name: 'check_environment',
  description: 'Fetch the available dataframes within the given compute environment',
  parameters: z.object({}),
  execute: async () => {
    const url = getPythonServerUrl();
    const res = await fetch(`${url}/environment/create`, {
      method: 'POST',
      body: JSON.stringify({
        // TODO: scope for each chat_id
        chat_id: '1',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    });
    const available_dataframes = await res.text();
    console.log(available_dataframes);
    return available_dataframes;
  }
})

export const runPythonTool = tool({
  name: 'run_python',
  description:
    'Provide lines of python code to be executed by a python interpreter. The results of stdout, stderr, & possible exceptions will be returned to you',
  parameters: z.object({ python_code: z.array(z.string()) }),
  execute: async ({ python_code }) => {
    console.log(python_code);
    const url = getPythonServerUrl();

    await fetch(`${url}/environment/create`, {
      method: 'POST',
      body: JSON.stringify({
        // TODO: scope for each chat_id
        chat_id: '1',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    });

    const result = await fetch(`${url}/execute`, {
      method: 'POST',
      body: JSON.stringify({
        chat_id: '1',
        code: python_code,
        language: 'python',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    });

    return await result.json();
  },
});

export const runSqlTool = tool({
  name: 'run_sql',
  description:
    'Provide SQL statement to be executed within a Jupyter kernel. The result of the SQL expression will be stored in a Pandas DataFrame called `sql_output`. You can interact with this result via the `run_python` tool. Since you are running within a `duckdb` environment, you can access available dataframes within your SQL statement. Example: `SELECT * FROM df`',
  parameters: z.object({ sql_statement: z.array(z.string()) }),
  execute: async ({ sql_statement }) => {
    console.log(sql_statement);
    const url = getPythonServerUrl();

    await fetch(`${url}/environment/create`, {
      method: 'POST',
      body: JSON.stringify({
        // TODO: scope for each chat_id
        chat_id: '1',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    });

    const result = await fetch(`${url}/execute`, {
      method: 'POST',
      body: JSON.stringify({
        chat_id: '1',
        code: sql_statement,
        language: 'sql',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    });

    return await result.json();
  },
});
