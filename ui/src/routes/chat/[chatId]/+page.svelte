<script lang="ts">
  import { createMessage, getChatMessages } from '$lib/api/chat.remote';

  let chat = $derived(await getChatMessages());
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

    <button type="submit">Send</button>
  </form>
{/if}
