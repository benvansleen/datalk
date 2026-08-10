<script lang="ts">
  import type { PageProps } from './$types';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { ArrowUp } from '@lucide/svelte';
  import { Spinner } from '$lib/components/shadcn/spinner';
  import * as Item from '$lib/components/shadcn/item';
  import MessageBlock from '$lib/components/message-block.svelte';
  import Sidebar from '$lib/components/sidebar.svelte';
  import {
    LiveClient,
    sendMessage,
    type LiveChatSummary,
    type LiveSnapshot,
  } from '$lib/live/client';

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
  let snapshot = $state<LiveSnapshot>({
    id: data.chatId,
    generating: data.currentMessageRequestId !== null,
    messages: data.messages.map((message, index) => ({
      id: String(index),
      role: message.role,
      content: message.content ?? '',
      createdAt: 0,
      toolName: message.name,
      toolArguments: message.arguments,
      toolResult: message.output,
    })),
    events: [],
  });
  let input = $state('');
  let error = $state('');
  let scrollToDiv: HTMLDivElement;

  onMount(() => {
    const userClient = new LiveClient(
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
        if (wire.type === 'chat-deleted' && !Array.isArray(wire.data)) {
          const chatId = (wire.data as { chatId: string }).chatId;
          chats = chats.filter((chat) => chat.id !== chatId);
          if (chatId === data.chatId) void goto('/');
        }
      },
    );
    userClient.start();
    return () => {
      userClient.stop();
    };
  });

  $effect(() => {
    const chatId = data.chatId;
    chats = data.chats.map((chat) => ({
      id: chat.id,
      dataset: chat.dataset,
      title: chat.title ?? '...',
      generating: chat.currentMessageRequest !== null,
      updatedAt: chat.updatedAt.getTime(),
    }));
    snapshot = {
      id: chatId,
      generating: data.currentMessageRequestId !== null,
      messages: data.messages.map((message, index) => ({
        id: String(index),
        role: message.role,
        content: message.content ?? '',
        createdAt: 0,
        toolName: message.name,
        toolArguments: message.arguments,
        toolResult: message.output,
      })),
      events: [],
    };
    input = '';
    error = '';
    window.scrollTo(0, 0);
    const client = new LiveClient(
      () =>
        `/live/chats/${chatId}/socket?after=${Math.max(0, ...snapshot.events.map((event) => event.sequence))}`,
      (message) => {
        if (!message || typeof message !== 'object' || !('type' in message) || !('data' in message))
          return;
        const wire = message as {
          type: string;
          data: LiveSnapshot | { sequence: number; type?: string; data?: unknown };
        };
        if (wire.type === 'snapshot') {
          snapshot = wire.data as LiveSnapshot;
          client.setSequence(Math.max(0, ...snapshot.events.map((event) => event.sequence)));
        }
        if (wire.type === 'event') {
          const event = wire.data as { sequence: number; type?: string; data?: unknown };
          client.setSequence(event.sequence);
          if (
            event.type === 'text-delta' &&
            typeof event.data === 'object' &&
            event.data !== null &&
            'id' in event.data &&
            'delta' in event.data
          ) {
            const { id, delta } = event.data as { id: string; delta: string };
            const index = snapshot.messages.findIndex((message) => message.id === id);
            snapshot = {
              ...snapshot,
              messages:
                index === -1
                  ? [
                      ...snapshot.messages,
                      { id, role: 'assistant', content: delta, createdAt: Date.now() },
                    ]
                  : snapshot.messages.map((message, messageIndex) =>
                      messageIndex === index
                        ? { ...message, content: message.content + delta }
                        : message,
                    ),
            };
          }
          if (
            event.type === 'tool-params-start' &&
            typeof event.data === 'object' &&
            event.data !== null &&
            'id' in event.data &&
            'name' in event.data
          ) {
            const { id, name } = event.data as { id: string; name: string };
            if (!snapshot.messages.some((message) => message.id === id)) {
              snapshot = {
                ...snapshot,
                messages: [
                  ...snapshot.messages,
                  {
                    id,
                    role: 'tool',
                    content: '',
                    createdAt: Date.now(),
                    toolName: name,
                    toolArguments: '',
                  },
                ],
              };
            }
          }
          if (
            event.type === 'tool-params-delta' &&
            typeof event.data === 'object' &&
            event.data !== null &&
            'id' in event.data &&
            'delta' in event.data
          ) {
            const { id, delta } = event.data as { id: string; delta: string };
            snapshot = {
              ...snapshot,
              messages: snapshot.messages.map((message) =>
                message.id === id
                  ? {
                      ...message,
                      toolArguments: `${typeof message.toolArguments === 'string' ? message.toolArguments : ''}${delta}`,
                    }
                  : message,
              ),
            };
          }
          if (
            event.type === 'tool-call' &&
            typeof event.data === 'object' &&
            event.data !== null &&
            'id' in event.data &&
            'name' in event.data &&
            'params' in event.data
          ) {
            const { id, name, params } = event.data as { id: string; name: string; params: string };
            const existing = snapshot.messages.some((message) => message.id === id);
            snapshot = {
              ...snapshot,
              messages: existing
                ? snapshot.messages.map((message) =>
                    message.id === id
                      ? { ...message, toolName: name, toolArguments: params }
                      : message,
                  )
                : [
                    ...snapshot.messages,
                    {
                      id,
                      role: 'tool',
                      content: '',
                      createdAt: Date.now(),
                      toolName: name,
                      toolArguments: params,
                    },
                  ],
            };
          }
          if (
            event.type === 'tool-result' &&
            typeof event.data === 'object' &&
            event.data !== null &&
            'id' in event.data &&
            'result' in event.data
          ) {
            const { id, result } = event.data as { id: string; result: unknown };
            snapshot = {
              ...snapshot,
              messages: snapshot.messages.map((message) =>
                message.id === id ? { ...message, toolResult: result } : message,
              ),
            };
          }
        }
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
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Unable to send message';
    }
  };
</script>

<Sidebar {chats} currentChatId={data.chatId}>
  <div class="m-20 grid gap-6">
    <div class="grid gap-2">
      {#each snapshot.messages as message}
        <MessageBlock
          role={message.role === 'tool' ? undefined : message.role}
          content={message.role === 'tool' ? undefined : message.content}
          name={message.toolName}
          arguments={typeof message.toolArguments === 'string'
            ? message.toolArguments
            : JSON.stringify(message.toolArguments ?? {})}
          output={message.toolResult}
        />
      {/each}
    </div>
    <form onsubmit={submit} class="grid gap-2">
      <div
        bind:this={scrollToDiv}
        class="mx-auto flex w-full max-w-2xl overflow-hidden rounded-md border"
      >
        <textarea
          bind:value={input}
          disabled={snapshot.generating}
          placeholder="Type your question... (shift+enter to send)"
          class="flex-1 resize-none px-4 py-2 focus:outline-none"
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
