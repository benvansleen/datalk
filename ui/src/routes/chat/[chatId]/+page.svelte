<script lang="ts">
  import { Button } from '$lib/components/shadcn/button';
  import { Spinner } from '$lib/components/shadcn/spinner';
  import { ArrowUp } from 'lucide-svelte';
  import { getChatMessages } from '$lib/api/chat.remote';

  import MessageBlock from '$lib/components/message-block.svelte';

  let { params } = $props();
  let chat = $derived(await getChatMessages(params.chatId));

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
  let toolState = $state('');
  let userInput = $state('');
  let submittedUserInput = $state('');
  let received_first_token = $state(false);
  let generating = $state(false);

  const handleSubmit = async (e: SubmitEvent) => {
    e.preventDefault();
    scrollToBottom();

    const res = await fetch(`/chat/${params.chatId}`, {
      method: 'POST',
      body: userInput,
      headers: {
        'Content-Type': 'text/plain',
      },
    });
    const messageRequestId = await res.text();
    console.log(messageRequestId);

    submittedUserInput = userInput;
    received_first_token = false;
    generating = true;
    (e.target as HTMLFormElement).reset();

    const eventSource = new EventSource(`/message-request/${messageRequestId}`);
    console.log(eventSource);

    eventSource.addEventListener('message', (e) => {
      scrollToBottom();

      const chunk = JSON.parse(e.data);
      if (chunk.type === 'content') {
        answer += chunk.text;
        received_first_token = true;
      }
      if (chunk.type === 'tool' && typeof chunk.status === 'string') {
        toolState = chunk.status;
      }
      if (chunk.type !== 'tool' && chunk.done) {
        generating = false;
        toolState = '';
        answer = '';
        submittedUserInput = '';
        getChatMessages(params.chatId).refresh();
      }
    });

    scrollToBottom();
  };
</script>

<Button variant="link" href="/">Go home</Button>

<div class="m-20 grid gap-6">
  <div class="grid gap-2">
    {#each chat.messages as { type, content }}
      <MessageBlock {type} {content} />
    {/each}

    {#if generating}
      <MessageBlock type="user" content={submittedUserInput} />
      {#if toolState}
        <MessageBlock type="tool" content={toolState} />
      {/if}

      {#if !received_first_token}
        <Spinner />
      {/if}
    {/if}

    {#if answer}
      <div bind:this={scrollToDiv}>
        <MessageBlock type="assistant" content={answer} />
      </div>
    {/if}
  </div>

  <form onsubmit={handleSubmit} class="grid gap-2">
    <div class="flex w-full max-w-2xl mx-auto border rounded-md overflow-hidden">
      <input
        bind:value={userInput}
        type="text"
        placeholder="Type your message..."
        class="flex-1 px-4 py-2 focus:outline-none"
      />
      <button type="submit" class="bg-blue-500 text-white px-4 py-2 hover:bg-blue-600">
        <ArrowUp class="w-5 h-5" />
      </button>
    </div>
  </form>
</div>
