<script lang="ts">
  import { enhance } from '$app/forms';
  import * as Item from '$lib/components/shadcn/item';
  import { Button } from '$lib/components/shadcn/button';
  import { SquareX } from 'lucide-svelte';

  const { chat } = $props();
</script>

<Item.Root variant="outline">
  <Item.Content class="flex flex-row justify-start">
    <form method="POST" action="/?/deleteChat" use:enhance>
      <input type="hidden" name="chatId" value={chat.id} />
      <Button variant="link" type="submit"><SquareX></SquareX></Button>
    </form>
    <div class="flex flex-row gap-2 items-center justify-between w-full">
      <Item.Title>{chat.title}</Item.Title>
      <Item.Actions>
        <Button variant="outline" size="sm" href={`/chat/${chat.id}`}>Open</Button>
      </Item.Actions>
    </div>
  </Item.Content>
</Item.Root>
