<script lang="ts">
  import { Button } from '$lib/components/shadcn/button';
  import { goto, invalidateAll } from '$app/navigation';
  import { page } from '$app/state';
  import { logout } from '$lib/api/auth.remote';

  let { data }: { data: { user?: any } } = $props();

  const handleLogout = async () => {
    try {
      await logout();
    } catch (error) {
      console.error('Logout failed:', error);
    } finally {
      invalidateAll();
      goto('/login');
    }
  };

  const navigationItems = [{ href: '/', label: 'Home' }];

  const currentPath = $derived(page.url.pathname);
  const showLoginLink = $derived(currentPath !== '/login');
  const showSignupLink = $derived(currentPath !== '/signup');
</script>

<header
  class="border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60"
>
  <div class="w-full px-4 flex h-14 items-center">
    <div class="mr-4 hidden md:flex">
      <a class="mr-6 flex items-center space-x-2" href="/">
        <span class="hidden font-bold sm:inline-block">Datalk</span>
      </a>
      <nav class="flex items-center space-x-6 text-sm font-medium">
        {#if data?.user}
          {#each navigationItems as item}
            <a
              href={item.href}
              class="transition-colors hover:text-foreground/80 text-foreground/60"
            >
              {item.label}
            </a>
          {/each}
        {/if}
      </nav>
    </div>

    <div class="flex flex-1 items-center justify-between space-x-2 md:justify-end md:items-center">
      <div class="w-full flex-1 md:w-auto md:flex-none">
        <!-- Search or other actions can go here -->
      </div>

      {#if data?.user}
        <div class="flex items-center space-x-3">
          <div class="hidden md:flex md:flex-col md:items-end md:leading-none">
            <p class="text-sm font-medium text-right">{data.user.name || data.user.email}</p>
            <p class="text-xs text-muted-foreground text-right">{data.user.email}</p>
          </div>
          <Button variant="ghost" size="sm" onclick={handleLogout}>Logout</Button>
        </div>
      {:else}
        <div class="flex items-center space-x-2">
          {#if showLoginLink}
            <Button variant="ghost" size="sm" href="/login">Login</Button>
          {/if}
          {#if showSignupLink}
            <Button variant="ghost" size="sm" href="/signup">Sign up</Button>
          {/if}
        </div>
      {/if}
    </div>
  </div>
</header>
