<script lang="ts">
  import { createChat, getChats } from '$lib/api/chat.remote';
  import { Spinner } from '$lib/components/shadcn/spinner';
  import * as Item from '$lib/components/shadcn/item';
  import { ArrowUp } from 'lucide-svelte';
  import { getChatMessages } from '$lib/api/chat.remote';
  import { fly, slide } from 'svelte/transition';

  import MessageBlock from '$lib/components/message-block.svelte';
  import Sidebar from '$lib/components/sidebar.svelte';

  let { params } = $props();
  let messages = $derived(await getChatMessages(params.chatId));

  // svelte-ignore non_reactive_update
  let scrollToDiv: HTMLDivElement;
  const scrollToBottom = () => {
    setTimeout(() => {
      if (scrollToDiv) {
        scrollToDiv.scrollIntoView({ behavior: 'smooth', block: 'end', inline: 'nearest' });
      }
    });
  };

  let answer = $state('');
  let toolState: string[] = $state(['']);
  let userInput = $state('');
  let submittedUserInput = $state('');
  let generating = $state(false);

  const handleSubmit = async (e: SubmitEvent) => {
    e.preventDefault();
    scrollToBottom();

    if (!userInput) {
      return;
    }

    const res = await fetch(`/chat/${params.chatId}`, {
      method: 'POST',
      body: userInput,
      headers: {
        'Content-Type': 'text/plain',
      },
    });
    const messageRequestId = await res.text();

    submittedUserInput = userInput;
    generating = true;
    (e.target as HTMLFormElement).reset();

    const eventSource = new EventSource(`/message-request/${messageRequestId}`);

    eventSource.addEventListener('message', (e) => {
      scrollToBottom();

      const chunk = JSON.parse(e.data);
      switch (chunk.type) {
        case 'response.output_text.delta': {
          answer += chunk.delta;
          break;
        }

        case 'response.function_call_arguments.delta': {
          let currentTool = toolState[toolState.length - 1];
          toolState[toolState.length - 1] = currentTool + chunk.delta;
          break;
        }

        case 'response.function_call_arguments.done': {
          toolState.push('');
          break;
        }

        case 'response_done': {
          console.log('Stream ended!');
          generating = false;
          toolState = [];
          answer = '';
          submittedUserInput = '';
          getChatMessages(params.chatId).refresh();
          setTimeout(() => {
            scrollToBottom();
          }, 500);
          break;
        }
      }
    });

    scrollToBottom();
  };
</script>


<Sidebar chats={await getChats()}>
  <div class="m-20 grid gap-6">
    <div class="grid gap-2">
      {#each messages as message}
        <MessageBlock {...message} />
      {/each}

      {#if generating}
        <div in:fly={{ y: 20, duration: 500 }}>
          <MessageBlock role="user" content={submittedUserInput} />
        </div>
        {#each toolState as tool}
          {#if tool}
            <div in:slide={{ duration: 200 }} out:slide={{ duration: 200 }}>
              <MessageBlock role="tool" arguments={tool} />
            </div>
          {/if}
        {/each}
      {/if}

      {#if answer}
        <div in:slide={{ duration: 100 }}>
          <MessageBlock role="assistant" content={answer} />
        </div>
      {/if}
    </div>

    <form onsubmit={handleSubmit} class="grid gap-2">
      <div
        bind:this={scrollToDiv}
        class="flex w-full max-w-2xl mx-auto border rounded-md overflow-hidden"
      >
        <textarea
          bind:value={userInput}
          placeholder="Type your question..."
          class="resize-none flex-1 px-4 py-2 focus:outline-none"
          rows="1"
          oninput={(e) => {
            e.target.style.height = 'auto';
            e.target.style.height = `${e.target.scrollHeight}px`;
          }}
          onkeydown={(e) => {
            if (e.key == 'Enter' && e.shiftKey) {
              e.preventDefault();
              e.target.style.height = 'auto';
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
