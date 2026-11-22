import 'dotenv/config';
import pg from 'pg';

const { Pool } = pg;
const rawUrl = process.env['DATABASE_URL']?.trim();
if (!rawUrl) throw new Error('DATABASE_URL is missing');

let dbUrl: URL;
try {
  dbUrl = new URL(rawUrl);
} catch {
  throw new Error('DATABASE_URL is invalid');
}

// Render external PostgreSQL endpoints require TLS.
const renderExternal = dbUrl.hostname.endsWith('.render.com') && dbUrl.hostname.includes('postgres');
const noVerify = dbUrl.searchParams.get('sslmode') === 'no-verify';
if (renderExternal) dbUrl.searchParams.delete('sslmode');

export const pgPool = new Pool({
  connectionString: renderExternal ? dbUrl.toString() : rawUrl,
  ssl: renderExternal ? { rejectUnauthorized: !noVerify } : undefined,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

pgPool.on('error', (error: Error & { code?: string }) => {
  console.error('[PostgreSQL] Idle client error:', error.code ?? 'UNKNOWN');
});
