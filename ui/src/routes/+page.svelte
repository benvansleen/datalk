<script lang="ts">
  import type { PageProps } from './$types';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { Button } from '$lib/components/shadcn/button';
  import * as Card from '$lib/components/shadcn/card';
  import * as Select from '$lib/components/shadcn/select/index.js';
  import Separator from '$lib/components/shadcn/separator/separator.svelte';
  import ChatSummary from '$lib/components/chat-summary.svelte';
  import { LiveClient, createChat, deleteChat, type LiveChatSummary } from '$lib/live/client';

  let { data }: PageProps = $props();
  let chats = $state<LiveChatSummary[]>(
    data.chats.map((chat) => ({
      id: chat.id,
      dataset: chat.dataset,
      title: chat.title ?? '...',
      generating: chat.currentMessageRequest !== null,
      updatedAt: chat.updatedAt.getTime(),
    })),
  );
  let dataset = $state('');
  let error = $state('');
  const triggerContent = $derived(
    data.datasets.find((item) => item === dataset) ?? 'Select a dataset',
  );
  const waitingChats = $derived(chats.filter((chat) => !chat.generating));
  const workingChats = $derived(chats.filter((chat) => chat.generating));

  onMount(() => {
    const client = new LiveClient(
      () => '/live/socket',
      (message) => {
        if (!message || typeof message !== 'object' || !('type' in message) || !('data' in message))
          return;
        const wire = message as {
          type: string;
          data: LiveChatSummary | LiveChatSummary[] | { chatId: string };
        };
        if (wire.type === 'snapshot' && Array.isArray(wire.data)) chats = wire.data;
        if (
          (wire.type === 'chat-created' || wire.type === 'chat-status') &&
          !Array.isArray(wire.data)
        )
          chats = [
            wire.data as LiveChatSummary,
            ...chats.filter((chat) => chat.id !== (wire.data as LiveChatSummary).id),
          ];
        if (wire.type === 'chat-deleted' && !Array.isArray(wire.data))
          chats = chats.filter((chat) => chat.id !== (wire.data as { chatId: string }).chatId);
      },
    );
    client.start();
    return () => client.stop();
  });

  const create = async () => {
    if (!dataset) return;
    try {
      await goto(`/chat/${(await createChat(dataset)).id}`);
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Unable to create chat';
    }
  };
</script>

<div class="grid h-screen place-items-center">
  <Card.Root class="w-full max-w-sm">
    <Card.Header class="flex flex-col items-center gap-3">
      <Select.Root type="single" bind:value={dataset} required>
        <Select.Trigger>{triggerContent}</Select.Trigger>
        <Select.Content>
          <Select.Group>
            <Select.Label>Datasets</Select.Label>
            {#each data.datasets as item}
              <Select.Item value={item} label={item}>{item}</Select.Item>
            {/each}
          </Select.Group>
        </Select.Content>
      </Select.Root>
      <Button onclick={create} disabled={!dataset}>Create new chat</Button>
      {#if error}<p class="text-sm text-red-600">{error}</p>{/if}
    </Card.Header>
    {#if chats.length > 0}
      <Card.Content class="grid gap-6">
        <Card.Title class="mx-auto w-fit">Chat Dashboard</Card.Title>
        <div class="grid max-h-128 gap-2 overflow-y-auto p-4">
          {#each workingChats as chat}
            <div class="bg-gray-200">
              <ChatSummary
                {chat}
                ondelete={(id) => deleteChat(id).catch((cause) => (error = String(cause)))}
              />
            </div>
          {:else}
            <p>No currently running chats</p>
          {/each}
          <Separator />
          {#each waitingChats as chat}
            <ChatSummary
              {chat}
              ondelete={(id) => deleteChat(id).catch((cause) => (error = String(cause)))}
            />
          {/each}
        </div>
      </Card.Content>
    {/if}
  </Card.Root>
</div>
