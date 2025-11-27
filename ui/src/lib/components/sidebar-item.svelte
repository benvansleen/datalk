<script lang="ts">
  import { goto } from '$app/navigation';
  import { Button } from '$lib/components/shadcn/button';

  const { Icon, label, collapsed, link } = $props();
</script>

<div class="relative group inline-block overflow-visible">
  <Button
    variant="ghost"
    class="flex items-center relative justify-start"
    onclick={() => goto(link)}
  >
    <Icon />

    {#if !collapsed}
      <span class="truncate w-45 text-start">{label}</span>
    {/if}
  </Button>
  <div
    class="
      absolute left-full top-1/2 -translate-y-1/2
      bg-white rounded shadow-lg p-3
      opacity-0 pointer-events-none
      group-hover:opacity-100
      transition-opacity duration-200
      z-50
      break-words min-w-70
    "
  >
    {label}
  </div>
</div>
