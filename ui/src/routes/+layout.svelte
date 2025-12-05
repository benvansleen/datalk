<script lang="ts">
  import '../app.css';
  import type { LayoutProps } from './$types';
  import favicon from '$lib/assets/favicon.svg';
  import '@fontsource/iosevka-aile/300.css';
  import Header from '$lib/components/header.svelte';

  let { children, data }: LayoutProps = $props();
</script>

<svelte:head>
  <link rel="icon" href={favicon} />
</svelte:head>

<Header {data} />

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
