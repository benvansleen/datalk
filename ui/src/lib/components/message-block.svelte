<script lang="ts">
  import * as Item from '$lib/components/shadcn/item';
  import { marked } from 'marked';
  import hljs from 'highlight.js/lib/core';
  import { onMount } from 'svelte';

  onMount(() => {
    hljs.highlightAll();
  });

  interface Props {
    role?: string;
    content?: string;
    name?: string;
    arguments?: string;
    output?: unknown;
  }

  const {
    role = undefined,
    content = undefined,
    name: fnName = undefined,
    arguments: args = undefined,
    output = undefined,
  }: Props = $props();

  const cleanFnName = (fnName: string | undefined): string => {
    switch (fnName) {
      case 'check_environment':
        return 'check environment';
      case 'run_python':
        return 'python';
      case 'run_sql':
        return 'sql';
      default:
        return fnName ?? 'tool';
    }
  };

  const parseFn = (args: string | undefined, output: unknown): string => {
    let result = '';

    if (args) {
      try {
        const parsed = JSON.parse(args);
        const { python_code, sql_statement } = parsed;
        if (python_code) {
          result += `
\`\`\`python
${python_code.join('\n')}
\`\`\`
`;
        }
        if (sql_statement) {
          result += `
\`\`\`sql
${sql_statement.join('\n')}
\`\`\`
`;
        }
      } catch {
        // If not valid JSON, just show the raw args
        result += args;
      }
    }

    // Handle output - can be a string or an object with text property
    let outputText: string | undefined;
    if (typeof output === 'string') {
      outputText = output;
    } else if (output && typeof output === 'object' && 'text' in output) {
      outputText = String(output.text);
    }
    if (outputText) {
      try {
        const parsed = JSON.parse(outputText);
        const outputs = parsed.outputs;
        if (outputs) {
          result += `
\`\`\`
> ${outputs}
\`\`\`
`;
        }
      } catch {
        // If not valid JSON, just show the raw output
        result += `
\`\`\`
> ${outputText}
\`\`\`
`;
      }
    }

    return result;
  };

  const finalRole = $derived(role ? role : cleanFnName(fnName));
  const finalContent = $derived(content ? content : parseFn(args, output));

  const roleStyle = (role: string): string => {
    switch (role) {
      case 'assistant':
        return 'bg-red-300';
      case 'user':
        return 'bg-blue-300';
      case 'python':
        return 'bg-green-300';
      case 'sql':
        return 'bg-yellow-300';
      default:
        return 'bg-purple-300';
    }
  };
</script>

<Item.Root class={`rounded-md px-0 py-0 grid grid-cols-1 gap-0 bg-gray-200`}>
  <div
    class={`${roleStyle(finalRole)} w-full capitalize text-gray-900 dark:text-gray-100 font-semibold px-4 py-2 rounded-t text-left`}
  >
    {finalRole}
  </div>
  {#if finalContent}
    <div class="markdown mx-6">
      {@html marked.parse(finalContent)}
    </div>
  {/if}
  <div class="min-h-2"></div>
</Item.Root>
