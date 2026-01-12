<script lang="ts">
  import type { PageProps } from './$types';
  import { enhance } from '$app/forms';
  import * as Card from '$lib/components/shadcn/card';
  import { Button } from '$lib/components/shadcn/button';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';

  let { form }: PageProps = $props();
</script>

<div class="grid place-items-center h-screen">
  <Card.Root class="w-full max-w-sm">
    <Card.Header class="">
      <Card.Title class="mx-auto w-fit">Sign Up</Card.Title>
      <Button variant="link" href="/login">Already have an account? Log in instead</Button>
    </Card.Header>
    <Card.Content>
      <form method="POST" use:enhance>
        <div class="flex flex-col gap-6">
          <div class="grid gap-2">
            <Label for="name">Username</Label>
            <Input
              name="name"
              type="text"
              placeholder="Your name"
              required
              value={form?.name ?? ''}
            />
          </div>

          <div class="grid gap-2">
            <Label for="email">Email</Label>
            <Input
              id="email"
              name="email"
              type="email"
              placeholder="m@example.com"
              required
              value={form?.email ?? ''}
            />
          </div>

          <div class="grid gap-2">
            <Label>Password</Label>
            <Input
              name="password"
              type="password"
              placeholder="Must be at least 8 characters"
              required
            />
          </div>

          {#if form?.error}
            <p class="text-red-800">{form.error}</p>
          {/if}

          <Button type="submit" class="w-full">Submit</Button>
        </div>
      </form>
    </Card.Content>
  </Card.Root>
</div>
