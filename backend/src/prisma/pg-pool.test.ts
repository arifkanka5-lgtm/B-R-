import { pgPool } from './pg-pool.js';

async function test() {
  const client = await pgPool.connect();

  try {
    await client.query('BEGIN');
    const result = await client.query('SELECT 1 AS connected');
    console.log('PostgreSQL:', result.rows[0]);
    await client.query('ROLLBACK');
    console.log('Transaction: BASARILI');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pgPool.end();
  }
}

test().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
