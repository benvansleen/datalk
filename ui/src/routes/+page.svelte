<script lang="ts">
  import type { PageProps } from './$types';
  import { invalidateAll } from '$app/navigation';
  import { Button } from '$lib/components/shadcn/button';
  import * as Card from '$lib/components/shadcn/card';
  import Separator from '$lib/components/shadcn/separator/separator.svelte';
  import ChatSummary from '$lib/components/chat-summary.svelte';

  let { data }: PageProps = $props();

  $effect(() => {
    const eventSource = new EventSource('/chat-status-events');
    eventSource.addEventListener('message', (_e) => {
      // Refresh data when chat status changes
      invalidateAll();
    });

    return () => {
      eventSource.close();
    };
  });

  const waitingChats = $derived(data.chats.filter((chat) => chat.currentMessageRequest === null));
  const workingChats = $derived(data.chats.filter((chat) => chat.currentMessageRequest !== null));

  import * as Select from '$lib/components/shadcn/select/index.js';

  let value = $state('');

  const triggerContent = $derived(data.datasets.find((d) => d === value) ?? 'Select a dataset');
</script>

<div class="grid place-items-center h-screen">
  <Card.Root class="w-full max-w-sm">
    <Card.Header class="flex flex-col items-center">
      <form method="POST" action="?/createChat" class="mx-auto w-fit">
        <Button type="submit" disabled={!value}>Create new chat</Button>
        <input type="hidden" name="dataset" value={triggerContent} />
      </form>
      <Select.Root type="single" bind:value required>
        <Select.Trigger>
          {triggerContent}
        </Select.Trigger>
        <Select.Content>
          <Select.Group>
            <Select.Label>Datasets</Select.Label>
            {#each data.datasets as dataset}
              <Select.Item value={dataset} label={dataset}>
                {dataset}
              </Select.Item>
            {/each}
          </Select.Group>
        </Select.Content>
      </Select.Root>
    </Card.Header>
    {#if data.chats.length > 0}
      <Card.Content class="grid gap-6">
        <Card.Title class="mx-auto w-fit">Chat Dashboard</Card.Title>
        <div class="grid gap-2 max-h-128 p-4 overflow-y-auto">
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
