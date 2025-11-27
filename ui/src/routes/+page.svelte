<script lang="ts">
  import { createChat, getChats } from '$lib/api/chat.remote';
  import { Button } from '$lib/components/shadcn/button';
  import * as Card from '$lib/components/shadcn/card';
  import Separator from '$lib/components/shadcn/separator/separator.svelte';
  import ChatSummary from '$lib/components/chat-summary.svelte';
  import { onMount } from 'svelte';

  let chats = $derived(await getChats());
  const waitingChats = $derived(chats.filter((chat) => chat.currentMessageRequest === null));
  const workingChats = $derived(chats.filter((chat) => chat.currentMessageRequest !== null));

  onMount(() => {
    const eventSource = new EventSource('/chat-status-events');
    eventSource.addEventListener('message', (e) => {
      const event = JSON.parse(e.data);
      switch (event.type) {
        /*
          This **should** be reactive -- but they're not! I suspect an issue w/ the experimental
          Svelte Remote Functions...
        */
        // case 'title-changed': {
        //   for (let i = 0; i < chats.length; i++) {
        //     if (chats[i].id === event.chatId) {
        //       console.log('updating title')
        //       chats[i].title = event.title;
        //     }
        //   }
        //   break;
        // }
        // case 'status-changed': {
        //   for (let i = 0; i < chats.length; i++) {
        //     if (chats[i].id === event.chatId) {
        //       console.log('updating status')
        //       chats[i].currentMessageRequest === event.currentMessageId;
        //     }
        //   }
        //   break;
        // }

        default: {
          // So instead, I am going to brute-force it...
          getChats().refresh();
          break;
        }
      }
    });
  });
</script>

<div class="grid place-items-center h-screen">
  <Card.Root class="w-full max-w-sm">
    <Card.Header>
      <form {...createChat} class="mx-auto w-fit">
        <Button type="submit">Create new chat</Button>
      </form>
    </Card.Header>
    {#if chats.length > 0}
      <Card.Content class="grid gap-6">
        <Card.Title class="mx-auto w-fit">Chat Dashboard</Card.Title>
        <div class="grid gap-2 max-h-128 overflow-y-auto">
          {#each workingChats as chat}
            <div class="bg-gray-200">
              <ChatSummary {chat} />
            </div>
          {:else}
            <p>No currently running chats</p>
          {/each}
          <Separator />
          {#each waitingChats as chat}
            <ChatSummary {chat} />
          {/each}
        </div>
      </Card.Content>
    {/if}
  </Card.Root>
</div>
