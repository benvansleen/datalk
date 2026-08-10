<script lang="ts">
  import * as Item from '$lib/components/shadcn/item';
  import { Button } from '$lib/components/shadcn/button';
  import { SquareX } from '@lucide/svelte';

  const { chat, ondelete } = $props<{
    chat: { id: string; title: string };
    ondelete?: (id: string) => void;
  }>();
</script>

<Item.Root variant="outline">
  <Item.Content class="flex flex-row justify-start">
    {#if ondelete}<Button variant="link" onclick={() => ondelete(chat.id)}><SquareX /></Button>{/if}
    <div class="flex flex-row gap-2 items-center justify-between w-full">
      <Item.Title>{chat.title}</Item.Title>
      <Item.Actions>
        <Button variant="outline" size="sm" href={`/chat/${chat.id}`}>Open</Button>
      </Item.Actions>
    </div>
  </Item.Content>
</Item.Root>
