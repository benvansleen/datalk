import { runPythonTool } from '$lib/server/responses/tools';
import { Agent } from '@openai/agents';

let model: Agent<unknown, 'text'>;
export const getModel = () => {
  if (!model) {
    model = new Agent({
      name: 'Datalk',
      instructions: 'Use markdown elements to enhance your answer',
      tools: [runPythonTool],
      model: 'gpt-5-nano',
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
