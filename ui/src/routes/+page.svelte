<script lang="ts">
  import { createChat } from '$lib/api/chat.remote';
</script>

<form {...createChat}>
  <button type="submit">Create new chat</button>

  {#if createChat.result}
    {createChat.result}
  {/if}
</form>
