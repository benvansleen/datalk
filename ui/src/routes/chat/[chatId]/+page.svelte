<script lang="ts">
  import { Button } from '$lib/components/ui/button';
  import { Spinner } from '$lib/components/ui/spinner';
  import { Input } from '$lib/components/ui/input/index.js';
  import * as Item from '$lib/components/ui/item';
  import SvelteMarkdown from '@humanspeak/svelte-markdown';
  import { getChatMessages } from '$lib/api/chat.remote';

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

    eventSource.addEventListener('message', (e: { data: string }) => {
      scrollToBottom();

      const chunk = JSON.parse(e.data);
      console.log(chunk);
      if (chunk.type === 'content') {
        answer += chunk.text;
        received_first_token = true;
      }
      if (chunk.type == 'tool') {
        answer += chunk.status;
      }
      if (chunk.done) {
        console.log('Stream ended!');
        generating = false;
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
      <Item.Root class="border border-gray-300 rounded-md px-4 py-2">
        <Item.Title class="min-w-20 font-bold">
          {type}:
        </Item.Title>
        <Item.Content>
          <SvelteMarkdown source={content} />
        </Item.Content>
      </Item.Root>
    {:else}
      <p>No messages yet!</p>
    {/each}

    {#if generating}
      <div class="border border-gray-300 rounded-md px-4 py-2">
        <SvelteMarkdown source={submittedUserInput} />
      </div>
      {#if !received_first_token}
        <Spinner />
      {/if}
    {/if}

    {#if answer}
      <div bind:this={scrollToDiv} class="border border-gray-300 rounded-md px-4 py-2">
        <SvelteMarkdown source={answer} />
      </div>
    {/if}
  </div>

  <form onsubmit={handleSubmit} class="grid gap-2">
    <Input type="text" class="input input-bordered w-full" bind:value={userInput}></Input>
    <Button type="submit">Send</Button>
  </form>
</div>
