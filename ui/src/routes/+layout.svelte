<script lang="ts">
  import '../app.css';
  import type { LayoutProps } from './$types';
  import favicon from '$lib/assets/favicon.svg';

  let { children }: LayoutProps = $props();
</script>

<svelte:head>
  <link rel="icon" href={favicon} />
</svelte:head>

{@render children()}
