<script lang="ts">
  import { signup, alreadyLoggedIn } from '$lib/api/auth.remote';
  alreadyLoggedIn();
</script>

<div>
  <h1>Sign up</h1>

  <form {...signup}>
    <label>
      Name
      <input {...signup.fields.name.as('text')} />
      {#each signup.fields.name.issues() as issue}
        <p class="issue">{issue.message}</p>
      {/each}
    </label>

    <label>
      Email
      <input {...signup.fields.email.as('text')} />
      {#each signup.fields.email.issues() as issue}
        <p class="issue">{issue.message}</p>
      {/each}
    </label>

    <label>
      Password
      <input {...signup.fields.password.as('password')} />
      {#each signup.fields.password.issues() as issue}
        <p class="issue">{issue.message}</p>
      {/each}
    </label>

    <button type="submit">Submit</button>

    {#if signup.result?.error}
      <p class="issue">{signup.result.error}</p>
    {/if}
  </form>

  <p>
    Already have an account?
    <a href="/login">Log in here instead!</a>
  </p>
</div>
