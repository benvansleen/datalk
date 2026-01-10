<script lang="ts">
  import type { PageProps } from './$types';
  import { invalidateAll } from '$app/navigation';
  import { Spinner } from '$lib/components/shadcn/spinner';
  import * as Item from '$lib/components/shadcn/item';
  import { ArrowUp } from '@lucide/svelte';
  import { fly, slide } from 'svelte/transition';

  import MessageBlock from '$lib/components/message-block.svelte';
  import Sidebar from '$lib/components/sidebar.svelte';

  let { data }: PageProps = $props();

  const pendingMessageContent = $derived(
    'currentMessageRequestContent' in data
      ? (data.currentMessageRequestContent)
      : null,
  );
  const hasPendingUserMessage = $derived(
    !!pendingMessageContent &&
      data.messages.some(
        (message) => message.role === 'user' && message.content === pendingMessageContent,
      ),
  );

  $effect(() => {
    const chatStatusEvents = new EventSource('/chat-status-events');
    chatStatusEvents.addEventListener('message', (e) => {
      const event = JSON.parse(e.data);
      if (event.type === 'chat-created' || event.type === 'chat-deleted') {
        invalidateAll();
      }
    });

    if (data.currentMessageRequestId) {
      console.log(`Resuming message request: ${data.currentMessageRequestId}`);
      if (pendingMessageContent && !hasPendingUserMessage && !submittedUserInput) {
        submittedUserInput = pendingMessageContent;
      }
      subscribe(data.currentMessageRequestId);
    }

    return () => {
      chatStatusEvents.close();
    };
  });

  // svelte-ignore non_reactive_update
  let scrollToDiv: HTMLDivElement;
  const scrollToBottom = () => {
    setTimeout(() => {
      if (scrollToDiv) {
        scrollToDiv.scrollIntoView({ behavior: 'smooth', block: 'end', inline: 'nearest' });
      }
    });
  };

  // Tool state: keyed by tool call ID
  interface ToolCall {
    id: string;
    name: string;
    params: string;
    result?: string;
  }

  let answer = $state('');
  let toolCalls = $state<Record<string, ToolCall>>({});
  let toolOrder = $state<string[]>([]); // Track order of tool calls
  let userInput = $state('');
  let submittedUserInput = $state('');
  let generating = $state(false);

  const resetGenerationState = () => {
    generating = false;
    toolCalls = {};
    toolOrder = [];
    answer = '';
    submittedUserInput = '';
  };

  const subscribe = (messageRequestId: string) => {
    const eventSource = new EventSource(`/message-request/${messageRequestId}`);
    generating = true;

    const cleanup = () => {
      eventSource.close();
      resetGenerationState();
    };

    eventSource.addEventListener('message', (e) => {
      scrollToBottom();

      const chunk = JSON.parse(e.data);
      switch (chunk.type) {
        // Text streaming
        case 'text-delta': {
          answer += chunk.delta;
          break;
        }

        // Tool parameter streaming (new format)
        case 'tool-params-start': {
          const id = chunk.id;
          if (!toolCalls[id]) {
            toolCalls[id] = { id, name: chunk.name, params: '' };
            toolOrder = [...toolOrder, id];
          }
          break;
        }

        case 'tool-params-delta': {
          const id = chunk.id;
          if (toolCalls[id]) {
            toolCalls[id] = { ...toolCalls[id], params: toolCalls[id].params + chunk.delta };
          }
          break;
        }

        case 'tool-params-end': {
          // Tool params complete, waiting for execution
          break;
        }

        // Complete tool call with parsed params
        case 'tool-call': {
          const id = chunk.id;
          if (!toolCalls[id]) {
            toolOrder = [...toolOrder, id];
          }
          toolCalls[id] = {
            id,
            name: chunk.name,
            params: typeof chunk.params === 'string' ? chunk.params : JSON.stringify(chunk.params),
          };
          break;
        }

        // Tool result
        case 'tool-result': {
          const id = chunk.id;
          if (toolCalls[id]) {
            toolCalls[id] = {
              ...toolCalls[id],
              result:
                typeof chunk.result === 'string' ? chunk.result : JSON.stringify(chunk.result),
            };
          }
          break;
        }

        // Finish events
        case 'finish': {
          // Intermediate finish event from model iterations - ignore
          // (only used during agentic loops between tool calls)
          break;
        }
        case 'response_error': {
          console.error('Generation error:', chunk.message);
          answer += `\n\n**Error:** ${chunk.message}`;
          break;
        }
        case 'response_done': {
          console.log('Stream ended!');
          cleanup();
          invalidateAll();
          setTimeout(() => {
            scrollToBottom();
          }, 500);
          break;
        }
      }
    });

    eventSource.addEventListener('error', () => {
      console.log('EventSource error, closing connection');
      cleanup();
    });
  };

  const handleSubmit = async (e: SubmitEvent) => {
    e.preventDefault();
    scrollToBottom();

    if (!userInput) {
      return;
    }

    const res = await fetch(`/chat/${data.chatId}`, {
      method: 'POST',
      body: userInput,
      headers: {
        'Content-Type': 'text/plain',
      },
    });
    const messageRequestId = await res.text();

    if (!res.ok) {
      console.error('Message request failed:', messageRequestId);
      resetGenerationState();
      answer += `\n\n**Error:** ${messageRequestId}`;
      return;
    }

    subscribe(messageRequestId);

    submittedUserInput = userInput;
    (e.target as HTMLFormElement).reset();

    scrollToBottom();
  };

  const historyToolCallIds = $derived(
    new Set(
      data.messages
        .filter((message) => message.role === 'tool')
        .map((message) => (message as { toolCallId?: string }).toolCallId)
        .filter((id): id is string => !!id),
    ),
  );

  // Derive tool state for rendering
  const activeToolCalls = $derived(
    toolOrder
      .map((id) => (toolCalls[id] ? { ...toolCalls[id], id } : null))
      .filter(
        (tool): tool is ToolCall => !!tool && !!tool.params && !historyToolCallIds.has(tool.id),
      ),
  );
</script>

<Sidebar chats={data.chats} currentChatId={data.chatId}>
  <div class="m-20 grid gap-6">
    <div class="grid gap-2">
      {#each data.messages as message}
        <MessageBlock {...message} />
      {/each}

      {#if generating}
        {#if submittedUserInput && !hasPendingUserMessage}
          <div in:fly={{ y: 20, duration: 500 }}>
            <MessageBlock role="user" content={submittedUserInput} />
          </div>
        {/if}
        {#each activeToolCalls as tool}
          <div in:slide={{ duration: 200 }} out:slide={{ duration: 200 }}>
            <MessageBlock
              role="tool"
              name={tool.name}
              arguments={tool.params}
              output={tool.result}
            />
          </div>
        {/each}
        {#if answer}
          <div in:slide={{ duration: 100 }}>
            <MessageBlock role="assistant" content={answer} />
          </div>
        {/if}
      {/if}
    </div>

    <form onsubmit={handleSubmit} class="grid gap-2">
      <div
        bind:this={scrollToDiv}
        class="flex w-full max-w-2xl mx-auto border rounded-md overflow-hidden"
      >
        <textarea
          bind:value={userInput}
          placeholder="Type your question... (shift+enter to send)"
          class="resize-none flex-1 px-4 py-2 focus:outline-none"
          rows="1"
          oninput={(e) => {
            const target = e.target as HTMLTextAreaElement;
            target.style.height = 'auto';
            target.style.height = `${target.scrollHeight}px`;
          }}
          onkeydown={(e) => {
            if (!generating && e.key == 'Enter' && e.shiftKey) {
              e.preventDefault();
              const target = e.target as HTMLTextAreaElement;
              target.style.height = 'auto';
              const form = e.currentTarget.closest('form');
              form?.requestSubmit();
            }
          }}
        ></textarea>

        {#if generating}
          <Item.Root variant="muted">
            <Item.Media>
              <Spinner />
            </Item.Media>
          </Item.Root>
        {:else}
          <button type="submit" class="bg-blue-500 text-white px-4 py-2 hover:bg-blue-600">
            <ArrowUp class="w-5 h-5" />
          </button>
        {/if}
      </div>
    </form>
  </div>
</Sidebar>
