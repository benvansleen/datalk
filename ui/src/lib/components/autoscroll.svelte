<script lang="ts">
  import { tick } from 'svelte';
  import type { LiveMessage } from '$lib/live/client';

  interface Props {
    messages: LiveMessage[];
  }

  const { messages }: Props = $props();

  let pinned = true;
  let lastHeight = 0;
  let lastCount = 0;
  let baselined = false;

  const isNearBottom = () =>
    window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 120;

  const scrollToBottom = (behavior: ScrollBehavior = 'smooth') =>
    window.scrollTo({ top: document.documentElement.scrollHeight, behavior });

  export function reset(toBottom = false) {
    baselined = false;
    pinned = true;
    if (toBottom) void tick().then(() => scrollToBottom('instant'));
    else window.scrollTo(0, 0);
  }

  export function pin() {
    pinned = true;
    scrollToBottom();
  }

  $effect(() => {
    const count = messages.length;
    void tick().then(() => {
      const height = document.documentElement.scrollHeight;
      if (!baselined) {
        baselined = true;
        lastHeight = height;
        lastCount = count;
        return;
      }
      const delta = height - lastHeight;
      if (pinned && delta > 0) {
        if (count !== lastCount) {
          scrollToBottom();
        } else {
          window.scrollBy({ top: delta, behavior: 'smooth' });
        }
      }
      lastHeight = height;
      lastCount = count;
    });
  });

  $effect(() => {
    const onIntent = () => {
      pinned = isNearBottom();
    };
    window.addEventListener('wheel', onIntent, { passive: true });
    window.addEventListener('touchmove', onIntent, { passive: true });
    window.addEventListener('keydown', onIntent);
    return () => {
      window.removeEventListener('wheel', onIntent);
      window.removeEventListener('touchmove', onIntent);
      window.removeEventListener('keydown', onIntent);
    };
  });
</script>
