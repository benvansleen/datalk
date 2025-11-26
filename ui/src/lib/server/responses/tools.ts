import { tool } from "@openai/agents";
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

export const runPythonTool = tool({
  name: 'run_python',
  description: 'Provide lines of python code to be executed by a python interpreter. The results of stdout, stderr, & possible exceptions will be returned to you',
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
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    });

    return await result.json();

  }

})
