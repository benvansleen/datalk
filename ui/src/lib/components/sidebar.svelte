<script lang="ts">
  import { Button } from '$lib/components/shadcn/button';
  import { Menu, ChevronLeft } from 'lucide-svelte';
  import SidebarItem from './sidebar-item.svelte';
  import { Home, Settings, User, MessageCircle } from 'lucide-svelte';
  let collapsed = $state(true);

  const { chats } = $props();
</script>

<div class="flex min-h-screen">
  <div
    class="
      flex flex-col bg-gray-200 transition-all duration-100
      border-r border-gray-200 text-neutral-900 rounded-md
    "
    style={`width: ${collapsed ? '4rem' : '16rem'}`}
  >
    <nav class="flex flex-col gap-1 p-3 overflow-visible">
      <Button class="justify-start" variant="ghost" onclick={() => (collapsed = !collapsed)}>
        {#if collapsed}
          <Menu class="" />
        {:else}
          <ChevronLeft class="" />
        {/if}
      </Button>
      <SidebarItem Icon={Home} label="Home" {collapsed} link="/" />
      {#each chats as chat}
        <SidebarItem
          Icon={MessageCircle}
          label={chat.title}
          {collapsed}
          link={`/chat/${chat.id}`}
        />
      {/each}
    </nav>
  </div>

  <div class="flex-1 p-6">
    <slot />
  </div>
</div>
