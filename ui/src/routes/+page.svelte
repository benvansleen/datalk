<script lang="ts">
  import { createChat, getChats } from '$lib/api/chat.remote';
  import { Button } from '$lib/components/shadcn/button';
  import * as Item from '$lib/components/shadcn/item';
  import * as Card from '$lib/components/shadcn/card';
</script>

<div class="grid place-items-center h-screen">
  <Card.Root class="w-full max-w-sm">
    <Card.Header>
      <form {...createChat} class="mx-auto w-fit">
        <Button type="submit">Create new chat</Button>
      </form>
    </Card.Header>
    <Card.Content class="grid gap-6">
      <Card.Title class="mx-auto w-fit">Historical Chats</Card.Title>
      <div class="grid gap-2 h-128 overflow-y-auto">
        {#each await getChats() as chat}
          <Item.Root variant="outline">
            <Item.Content class="flex flex-row items-center justify-between">
              <Item.Title>{chat.title}</Item.Title>
              <Item.Actions>
                <Button variant="outline" size="sm" href={`/chat/${chat.id}`}>Open</Button>
              </Item.Actions>
            </Item.Content>
          </Item.Root>
        {/each}
      </div>
    </Card.Content>
  </Card.Root>
</div>
