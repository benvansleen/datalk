import type { CacheConfig } from 'drizzle-orm/cache/core/types';
import { getTableName, is, Table } from 'drizzle-orm';
import { Cache } from 'drizzle-orm/cache/core';
import Keyv from 'keyv';
import KeyvRedis from '@keyv/redis';
import { env } from '$env/dynamic/private';

let redisUrl: string;
const getRedisUrl = () => {
  if (!redisUrl) {
    const { REDIS_USER, REDIS_PASSWORD, REDIS_HOST, REDIS_PORT } = env;
    redisUrl = `redis://${REDIS_USER}:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}`;
    console.log(`Using: ${redisUrl}`);
  }
  return redisUrl;
};

export class RedisCache extends Cache {
  private globalTtl: number = 1000;
  private usedTablesPerKey: Record<string, string[]> = {};

  constructor(private kv: Keyv = new Keyv(new KeyvRedis(getRedisUrl()))) {
    console.log(kv);
    super();
  }

  override strategy(): 'explicit' | 'all' {
    return 'all';
  }

  override async get(key: string): Promise<any[] | undefined> {
    const res = (await this.kv.get(key)) ?? undefined;
    console.log(`GET key: ${key}, value: ${JSON.stringify(res)}`);
    return res;
  }

  override async put(
    key: string,
    response: any,
    tables: string[],
    config?: CacheConfig,
  ): Promise<void> {
    const ttl = config?.px ?? (config?.ex ? config.ex * 1000 : this.globalTtl);
    await this.kv.set(key, response, ttl);
    console.log(`PUT key: ${key}, value: ${JSON.stringify(response)}`);
    for (const table of tables) {
      const keys = this.usedTablesPerKey[table];
      if (keys === undefined) {
        this.usedTablesPerKey[table] = [key];
      } else {
        keys.push(key);
      }
    }
  }

  override async onMutate(params: {
    tags: string | string[];
    tables: string | string[] | Table<any> | Table<any>[];
  }): Promise<void> {
    console.log(`INVALIDATING: ${JSON.stringify(params)}`);
    const tagsArray = params.tags ? (Array.isArray(params.tags) ? params.tags : [params.tags]) : [];
    const tablesArray = params.tables
      ? Array.isArray(params.tables)
        ? params.tables
        : [params.tables]
      : [];

    const keysToDelete = new Set<string>();
    for (const table of tablesArray) {
      const tableName = is(table, Table) ? getTableName(table) : (table as string);
      const keys = this.usedTablesPerKey[tableName] ?? [];
      for (const key of keys) keysToDelete.add(key);
    }
    console.log(keysToDelete.size);

    if (keysToDelete.size > 0 || tagsArray.length > 0) {
      for (const tag of tagsArray) {
        await this.kv.delete(tag);
      }

      for (const key of keysToDelete) {
        await this.kv.delete(key);
        for (const table of tablesArray) {
          const tableName = is(table, Table) ? getTableName(table) : (table as string);
          this.usedTablesPerKey[tableName] = [];
        }
      }
    }
  }
}
