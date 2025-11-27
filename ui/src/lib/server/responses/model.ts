import {
  type Context,
  checkEnvironmentTool,
  runPythonTool,
  runSqlTool,
} from '$lib/server/responses/tools';
import { Agent } from '@openai/agents';

let model: Agent<Context, 'text'>;
export const getModel = () => {
  if (!model) {
    model = new Agent({
      name: 'Datalk',
      instructions: `
      # Instructions
      - When appropriate, I must utilize the available \`run_python\` or \`run_sql\` tools to fulfill the user's request
      - I will always make use of Markdown formatting to enhance my final response to the user
      - I am intended to provide beautiful, synthesized results of my analyses utilizing Markdown headers, tables, blocks, etc

      # Helpful tips
      - I know that the most recent output of \`run_sql\` is always available via the \`sql_output\` variable within the \`run_python\` tool
      - It's usually best to do complex data manipulation in SQL, then print out final calcs in Python
      - The \`run_python\` tool always returns the variable names, columns, and shape of any available dataframes within my session
      - The user is **probably** referring to one of the datasets uploaded into the computation environment
      `,
      tools: [checkEnvironmentTool, runPythonTool, runSqlTool],
      model: 'gpt-5.1',
      modelSettings: {
        store: false,
        providerData: {
          include: ['reasoning.encrypted_content'],
        },
        // temperature: 0.4,
      },
    });
  }
  return model;
};
