<script lang="ts">
  import { Button } from '$lib/components/ui/button';
  import { Label } from '$lib/components/ui/label';
  import { Input } from '$lib/components/ui/input';
  import * as Card from '$lib/components/ui/card';
  import { login, alreadyLoggedIn } from '$lib/api/auth.remote';

  alreadyLoggedIn();
</script>

<div class="grid place-items-center h-screen">
  <Card.Root class="w-full max-w-sm">
    <Card.Header class="">
      <Card.Title class="mx-auto w-fit">Login</Card.Title>
      <Button variant="link" href="/signup">Don't have an account? Sign up instead</Button>
    </Card.Header>
    <Card.Content>
      <form {...login.enhance(async ({ submit }) => submit())}>
        <div class="flex flex-col gap-6">
          <div class="grid gap-2">
            <Label>Email</Label>
            <Input placeholder="m@example.com" required {...login.fields.email.as('email')} />
            {#each login.fields.email.issues() as issue}
              <p class="text-red-800">{issue.message}</p>
            {/each}
          </div>

          <div class="grid gap-2">
            <Label>Password</Label>
            <Input required {...login.fields.password.as('password')} />
            {#each login.fields.password.issues() as issue}
              <p class="text-red-800">{issue.message}</p>
            {/each}
          </div>
          {#if login.result?.error}
            <p class="text-red-800">{login.result.error}</p>
          {/if}
          <Button type="submit" class="w-full">Login</Button>
        </div>
      </form>
    </Card.Content>
  </Card.Root>
</div>
