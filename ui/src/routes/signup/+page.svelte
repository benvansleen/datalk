<script lang="ts">
  import * as Card from '$lib/components/shadcn/card';
  import { Button } from '$lib/components/shadcn/button';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import { signup, alreadyLoggedIn } from '$lib/api/auth.remote';

  alreadyLoggedIn();
</script>

<div class="grid place-items-center h-screen">
  <Card.Root class="w-full max-w-sm">
    <Card.Header class="">
      <Card.Title class="mx-auto w-fit">Sign Up</Card.Title>
      <Button variant="link" href="/login">Already have an account? Log in instead</Button>
    </Card.Header>
    <Card.Content>
      <form {...signup.enhance(async ({ submit }) => submit())}>
        <div class="flex flex-col gap-6">
          <div class="grid gap-2">
            <Label for="name">Username</Label>
            <Input placeholder="Your name" required {...signup.fields.name.as('text')} />
            {#each signup.fields.name.issues() as issue}
              <p class="text-red-800">{issue.message}</p>
            {/each}
          </div>

          <div class="grid gap-2">
            <Label for="email">Email</Label>
            <Input
              id="email"
              placeholder="m@example.com"
              required
              {...signup.fields.email.as('email')}
            />
            {#each signup.fields.email.issues() as issue}
              <p class="text-red-800">{issue.message}</p>
            {/each}
          </div>

          <div class="grid gap-2">
            <Label>Password</Label>
            <Input
              placeholder="Must be at least 8 characters"
              required
              {...signup.fields.password.as('password')}
            />
            {#each signup.fields.password.issues() as issue}
              <p class="text-red-800">{issue.message}</p>
            {/each}
          </div>

          {#if signup.result?.error}
            <p class="text-red-800">{signup.result.error}</p>
          {/if}
          <Button type="submit" class="w-full">Submit</Button>
        </div>
      </form>
    </Card.Content>
  </Card.Root>
</div>
