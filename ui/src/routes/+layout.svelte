<script lang="ts">
  import '../app.css';
  import type { LayoutProps } from './$types';
  import favicon from '$lib/assets/favicon.svg';
  import '@fontsource/iosevka-aile/300.css';

  let { children }: LayoutProps = $props();
</script>

<svelte:head>
  <link rel="icon" href={favicon} />
</svelte:head>

{@render children()}

<style>
  :global(body) {
    font-family:
      'Iosevka Aile',
      system-ui,
      -apple-system,
      sans-serif;
  }
</style>
