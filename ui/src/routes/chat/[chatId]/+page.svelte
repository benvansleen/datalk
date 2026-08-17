<script lang="ts">
  import type { PageProps } from './$types';
  import { goto } from '$app/navigation';
  import { resolve } from '$app/paths';
  import { onMount } from 'svelte';
  import { ArrowUp } from '@lucide/svelte';
  import Autoscroll from '$lib/components/autoscroll.svelte';
  import { Spinner } from '$lib/components/shadcn/spinner';
  import * as Item from '$lib/components/shadcn/item';
  import MessageBlock from '$lib/components/message-block.svelte';
  import Sidebar from '$lib/components/sidebar.svelte';
  import {
    LiveClient,
    deletedChatId,
    reduceChats,
    reduceSnapshot,
    sendMessage,
    toLiveChats,
    toLiveMessages,
    type LiveChatSummary,
    type LiveSnapshot,
  } from '$lib/live/client';

  let { data }: PageProps = $props();
  let chats = $state<LiveChatSummary[]>(toLiveChats(data.chats));
  let snapshot = $state<LiveSnapshot>({
    id: data.chatId,
    generating: data.currentMessageRequestId !== null,
    messages: toLiveMessages(data.messages),
    events: [],
  });
  let input = $state('');
  let error = $state('');
  let formEl: HTMLFormElement;
  let autoscroll: Autoscroll | undefined;

  onMount(() => {
    const userClient = new LiveClient(
      () => '/live/socket',
      (message) => {
        if (deletedChatId(message) === data.chatId) void goto(resolve('/'));
        chats = reduceChats(chats, message);
      },
    );
    userClient.start();
    return () => {
      userClient.stop();
    };
  });

  $effect(() => {
    const chatId = data.chatId;
    chats = toLiveChats(data.chats);
    snapshot = {
      id: chatId,
      generating: data.currentMessageRequestId !== null,
      messages: toLiveMessages(data.messages),
      events: [],
    };
    input = '';
    error = '';
    autoscroll?.reset(data.currentMessageRequestId !== null);
    const client = new LiveClient(
      () => `/live/chats/${chatId}/socket`,
      (message) => {
        snapshot = reduceSnapshot(snapshot, message);
      },
    );
    client.start();
    return () => client.stop();
  });

  const submit = async (event: SubmitEvent) => {
    event.preventDefault();
    if (!input || snapshot.generating) return;
    try {
      await sendMessage(data.chatId, input);
      input = '';
      autoscroll?.pin();
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Unable to send message';
    }
  };

  const handleKeydown = (event: KeyboardEvent) => {
    if (event.key !== 'Enter') return;
    if (event.shiftKey) {
      event.preventDefault();
      formEl?.requestSubmit();
    }
  };
</script>

<Sidebar {chats} currentChatId={data.chatId}>
  <Autoscroll messages={snapshot.messages} bind:this={autoscroll} />
  <div class="m-20 grid gap-6">
    <div class="grid gap-2">
      {#each snapshot.messages.filter((message) => message.role !== 'assistant' || message.content) as message (message.id)}
        <MessageBlock
          role={message.role === 'tool' ? undefined : message.role}
          content={message.role === 'tool' ? undefined : message.content}
          name={message.toolName}
          arguments={typeof message.toolArguments === 'string'
            ? message.toolArguments
            : JSON.stringify(message.toolArguments ?? {})}
          output={message.toolResult}
          chatId={data.chatId}
          images={message.images}
        />
      {/each}
    </div>
    <form bind:this={formEl} onsubmit={submit} class="grid gap-2">
      <div class="mx-auto flex w-full max-w-2xl overflow-hidden rounded-md border">
        <textarea
          bind:value={input}
          onkeydown={handleKeydown}
          disabled={snapshot.generating}
          placeholder="Type your question... (shift+enter to send)"
          class="field-sizing-content max-h-64 flex-1 resize-none overflow-y-auto px-4 py-2 focus:outline-none"
          rows="1"></textarea>
        {#if snapshot.generating}
          <Item.Root variant="muted"><Item.Media><Spinner /></Item.Media></Item.Root>
        {:else}
          <button type="submit" class="bg-blue-500 px-4 py-2 text-white hover:bg-blue-600"
            ><ArrowUp class="w-5 h-5" /></button
          >
        {/if}
      </div>
    </form>
    {#if error}<p class="text-sm text-red-600">{error}</p>{/if}
  </div>
</Sidebar>
