<script lang="ts">
  import { login } from '$lib/api/auth.remote';
</script>

<div>
  <h1>Log in</h1>

  <form {...login}>
    <label>
      Email
      <input {...login.fields.email.as('email')} />
      {#each login.fields.email.issues() as issue}
        <p class="issue">{issue.message}</p>
      {/each}
    </label>

    <label>
      Password
      <input {...login.fields.password.as('password')} />
      {#each login.fields.password.issues() as issue}
        <p class="issue">{issue.message}</p>
      {/each}
    </label>

    <p>
      Don't have an account yet?
      <a href="/signup">Sign up here</a>
    </p>

    <button type="submit">Submit</button>
  </form>
</div>
