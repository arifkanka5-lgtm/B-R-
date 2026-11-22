import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { AppService } from './app.service.js';
import { pgPool } from './prisma/pg-pool.js';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get('health/db')
  async databaseHealth() {
    try {
      const result = await pgPool.query<{ count: number }>('SELECT COUNT(*)::int AS count FROM "Gift"');
      return { status: 'ok', giftCount: result.rows[0]?.count ?? 0 };
    } catch (error: unknown) {
      const e = error as { code?: string; message?: string };
      const code = typeof e.code === 'string' ? e.code : 'UNKNOWN';
      const message = typeof e.message === 'string' ? e.message : '';
      const reason = code === 'ENOTFOUND' ? 'DNS_ERROR'
        : code === '28P01' ? 'BAD_PASSWORD'
        : code === '42P01' ? 'MISSING_TABLE'
        : code === 'ECONNREFUSED' ? 'CONNECTION_REFUSED'
        : /certificate|self.signed/i.test(message) ? 'TLS_CERTIFICATE_ERROR'
        : /ssl|pg_hba/i.test(message) ? 'TLS_OR_ACCESS_ERROR'
        : 'DATABASE_ERROR';
      console.error('[DB_HEALTH]', { code, reason });
      throw new ServiceUnavailableException({ status: 'error', code, reason });
    }
  }

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }
}
