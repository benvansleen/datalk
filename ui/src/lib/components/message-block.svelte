<script lang="ts">
  import * as Item from '$lib/components/shadcn/item';
  import { marked } from 'marked';
  import hljs from 'highlight.js/lib/core';
  import { onMount } from 'svelte';

  onMount(() => {
    hljs.highlightAll();
  });

  const {
    role = undefined,
    content = undefined,
    name: fnName = undefined,
    arguments: args = undefined,
    output = undefined,
  } = $props();

  const cleanFnName = (fnName: any) => {
    switch (fnName) {
      case 'run_python': {
        return 'python';
      }

      default: {
        return fnName;
      }
    }
  };

  const parsedArgs = $derived(args ? JSON.parse(args) : undefined);
  const parsedOutput = $derived(output ? JSON.parse(output.text) : undefined);

  const finalRole = $derived(role ? role : cleanFnName(fnName));
  const finalContent = $derived(content
    ? content
    : `
\`\`\`python
${parsedArgs.python_code.join('\n')}
\`\`\`

\`\`\`
> ${parsedOutput.outputs}
\`\`\`
  `);

  console.log(finalContent);

  const roleStyle = (role: string): string => {
    switch (role) {
      case 'assistant':
        return 'bg-red-300';
      case 'user':
        return 'bg-blue-300';
      case 'python':
        return 'bg-green-300';
      default:
        return 'bg-purple-300';
    }
  };
</script>

<Item.Root class={`border border-gray-300 rounded-md px-0 py-0 grid grid-cols-1 gap-0 bg-gray-200`}>
  <div
    class={`${roleStyle(finalRole)} w-full capitalize text-gray-900 dark:text-gray-100 font-semibold px-4 py-2 rounded-t text-left`}
  >
    {finalRole}
  </div>
  <div class="markdown mx-6">
    {@html marked.parse(finalContent)}
  </div>
</Item.Root>
