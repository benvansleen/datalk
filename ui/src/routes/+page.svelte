<script lang="ts">
  import { requireAuth } from '$lib/api/auth.remote';

  const _ = requireAuth();

  let x = $state(0);
  function increment() {
    x += 1;
  }
</script>

<h1 class="prose">test!</h1>
<p>Visit <a href="https://svelte.dev/docs/kit">svelte.dev/docs/kit</a> to read the documentation</p>

<button onclick={increment}>increment</button>
<p>{x}</p>
