<script lang="ts">
  import type { PageProps } from './$types';
  import { enhance } from '$app/forms';
  import { Button } from '$lib/components/shadcn/button';
  import { Label } from '$lib/components/shadcn/label';
  import { Input } from '$lib/components/shadcn/input';
  import * as Card from '$lib/components/shadcn/card';

  let { form }: PageProps = $props();
</script>

<div class="grid place-items-center h-screen">
  <Card.Root class="w-full max-w-sm">
    <Card.Header class="">
      <Card.Title class="mx-auto w-fit">Login</Card.Title>
      <Button variant="link" href="/signup">Don't have an account? Sign up instead</Button>
    </Card.Header>
    <Card.Content>
      <form method="POST" use:enhance>
        <div class="flex flex-col gap-6">
          <div class="grid gap-2">
            <Label>Email</Label>
            <Input
              name="email"
              type="email"
              placeholder="m@example.com"
              required
              value={form?.email ?? ''}
            />
          </div>

          <div class="grid gap-2">
            <Label>Password</Label>
            <Input name="password" type="password" required />
          </div>

          {#if form?.error}
            <p class="text-red-800">{form.error}</p>
          {/if}

          <Button type="submit" class="w-full">Login</Button>
        </div>
      </form>
    </Card.Content>
  </Card.Root>
</div>
