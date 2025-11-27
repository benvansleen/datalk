<script lang="ts">
  import { createChat, getChats } from '$lib/api/chat.remote';
  import { Button } from '$lib/components/shadcn/button';
  import * as Card from '$lib/components/shadcn/card';
  import Separator from '$lib/components/shadcn/separator/separator.svelte';
  import ChatSummary from '$lib/components/chat-summary.svelte';

  const chats = await getChats();
  const waitingChats = chats.filter((chat) => chat.currentMessageRequest === null);
  const workingChats = chats.filter((chat) => chat.currentMessageRequest !== null);
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
            <ChatSummary {chat} />
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
