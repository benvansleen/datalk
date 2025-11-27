import { createClient } from 'redis';
import { getRedisUrl } from '$lib/server/db/cache';

export const getRedis = async () => {
  const redis = createClient({ url: getRedisUrl() });
  await redis.connect();
  return redis;
}
