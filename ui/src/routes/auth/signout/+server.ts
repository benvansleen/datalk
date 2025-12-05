import { getAuth } from '$lib/server/auth';
import { redirect } from '@sveltejs/kit';

export const POST = async (event) => {
  try {
    const auth = getAuth();
    await auth.api.signOut({
      headers: event.request.headers,
    });
  } catch (error) {
    console.error('Signout error:', error);
  }

  redirect(303, '/login');
};
