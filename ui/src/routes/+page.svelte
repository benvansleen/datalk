<script>
  let x = $state(0);
  function increment() {
    x += 1;
  }

  import { getUsers, createUser } from './page.remote';
</script>

<h1 class="prose">test!</h1>
<p>Visit <a href="https://svelte.dev/docs/kit">svelte.dev/docs/kit</a> to read the documentation</p>

<button onclick={increment}>increment</button>
<p>{x}</p>

<form {...createUser}>
  <label>
    <h2>Full name</h2>
    <input {...createUser.fields.full_name.as('text')} />
  </label>
  <label>
    <h2>Email</h2>
    <input {...createUser.fields.email.as('text')} />
  </label>
  <button>Submit</button>
</form>

<ul>
  {#each await getUsers() as { full_name, email }}
    <li>{full_name}: {email}</li>
  {/each}
</ul>
