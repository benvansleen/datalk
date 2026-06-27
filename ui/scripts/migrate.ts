import postgres from 'postgres';
import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';

const sql = postgres({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: false,
  max: 1,
});
const db = drizzle(sql);

const connectWithRetry = async () => {
  const attempts = 60;
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      await sql`select 1`;
    } catch (error) {
      console.log(`waiting for database (${attempt}/${attempts})`);
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
};

await connectWithRetry();
await sql`select pg_advisory_lock(hashtext('datalk-drizzle-migrations'))`;

try {
  await migrate(db, { migrationsFolder: './drizzle' });
} finally {
  await sql`select pg_advisory_unlock(hashtext('datalk-drizzle-migrations'))`;
  await sql.end();
}
