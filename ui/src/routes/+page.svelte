<script lang="ts">
  import { createChat, getChats } from '$lib/api/chat.remote';
</script>

<div class="mx-auto w-fit my-4 grid grid-cols-1 gap-10">
  <section>
    <form {...createChat}>
      <button
        type="submit"
        class="px-8 py-4 text-lg font-semibold rounded-xl
  border-2 border-indigo-600 text-indigo-600
  hover:bg-indigo-600 hover:text-white
  transition">Create new chat</button
      >

      {#if createChat.result}
        {createChat.result}
      {/if}
    </form>
  </section>

  <section class="">
    <h1 class="text-lg tracking-wide">Historical chats</h1>
    <ol class="list-decimal pl-4">
      {#each await getChats() as chat}
        <li><a href={`/chat/${chat.id}`}>{chat.title}</a></li>
      {/each}
    </ol>
  </section>
</div>
