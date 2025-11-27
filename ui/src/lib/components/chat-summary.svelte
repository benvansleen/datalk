<script lang="ts">
  import * as Item from '$lib/components/shadcn/item';
  import { Button } from '$lib/components/shadcn/button';

  const { chat } = $props();
</script>

<Item.Root variant="outline">
  <Item.Content class="flex flex-row items-center justify-between">
    <Item.Title>{chat.title}</Item.Title>
    <Item.Actions>
      <Button variant="outline" size="sm" href={`/chat/${chat.id}`}>Open</Button>
    </Item.Actions>
  </Item.Content>
</Item.Root>
