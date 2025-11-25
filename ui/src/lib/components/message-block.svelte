<script lang="ts">
  import * as Item from '$lib/components/shadcn/item';
  import { marked } from 'marked';
  import hljs from 'highlight.js/lib/core';
  import { onMount } from 'svelte';

  onMount(() => {
    hljs.highlightAll();
  });

  export let type: string;
  export let content: string;

  if (type === 'tool') {
    try {
      const call = JSON.parse(content);
      if (call.params.python_code) {
        type = 'python';
        content = `
\`\`\`python
${call.params.python_code.join('\n')}
\`\`\`

\`\`\`
> ${call.result.outputs}
\`\`\`
`;
      }
    } catch (err) {}
  }

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
    class={`${roleStyle(type)} w-full capitalize text-gray-900 dark:text-gray-100 font-semibold px-4 py-2 rounded-t text-left`}
  >
    {type}
  </div>
  <div class="markdown mx-6">
    {@html marked.parse(content)}
  </div>
</Item.Root>
