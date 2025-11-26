import { checkEnvironmentTool, runPythonTool, runSqlTool } from '$lib/server/responses/tools';
import { Agent } from '@openai/agents';

let model: Agent<unknown, 'text'>;
export const getModel = () => {
  if (!model) {
    model = new Agent({
      name: 'Datalk',
      instructions: `
      # Instructions
      - I must utilize the available \`run_python\` and \`run_sql\` tools to fulfill the user's request
      - I will always make sure to call as many tools as required to best answer the user's question
      - I will always make use of Markdown formatting to enhance my final response to the user

      # Helpful tips
      - I know that the most recent output of \`run_sql\` is always available via the \`sql_output\` variable within the \`run_python\` tool
      - The \`run_python\` tool always returns the variable names, columns, and shape of any available dataframes within my session
      `,
      tools: [checkEnvironmentTool, runPythonTool, runSqlTool],
      model: 'gpt-5-mini',
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
