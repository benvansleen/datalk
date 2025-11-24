<script lang="ts">
  import { createMessage, getChatMessages } from '$lib/api/chat.remote';

  let { params } = $props();
  let chat = $derived(await getChatMessages(params.chatId));
</script>

<h1>welcome to chat: {chat.title} ({chat.id})</h1>

{#each chat.messages as message}
  <p>{message.type}: {message.content}</p>
{:else}
  <p>No messages yet!</p>
{/each}

{#if chat.messages}
  <form {...createMessage}>
    <label>
      <input {...createMessage.fields.content.as('text')} />
    </label>

    <input {...createMessage.fields.chatId.as('hidden', params.chatId)} />
    <button type="submit">Send</button>
  </form>
{/if}
