import {
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { pgPool } from '../prisma/pg-pool.js';

@Injectable()
export class WalletService {
  async getWallet(userPublicId: string) {
    const client = await pgPool.connect();

    try {
      await client.query('BEGIN');

      const user = await client.query(
        `SELECT id FROM "User"
         WHERE "publicId" = $1 AND "isActive" = true`,
        [userPublicId],
      );

      if (!user.rowCount) {
        throw new UnauthorizedException('Kullanici bulunamadi.');
      }

      const userId = user.rows[0].id;

      await client.query(
        `INSERT INTO "Wallet" ("userId")
         VALUES ($1)
         ON CONFLICT ("userId") DO NOTHING`,
        [userId],
      );

      const result = await client.query(
        `SELECT id, "userId", balance, "createdAt", "updatedAt"
         FROM "Wallet"
         WHERE "userId" = $1`,
        [userId],
      );

      await client.query('COMMIT');

      return {
        walletId: result.rows[0].id,
        balance: result.rows[0].balance.toString(),
        currency: 'COIN',
      };
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async getTransactions(userPublicId: string, page = 1) {
    const wallet = await this.getWallet(userPublicId);
    const limit = 50;
    const offset = (page - 1) * limit;

    const result = await pgPool.query(
      `SELECT id, type, amount, "balanceAfter",
              description, "referenceId", "createdAt"
       FROM "CoinTransaction"
       WHERE "userId" = (
         SELECT id FROM "User" WHERE "publicId" = $1
       )
       ORDER BY "createdAt" DESC, id DESC
       LIMIT $2 OFFSET $3`,
      [userPublicId, limit, offset],
    );

    return {
      wallet,
      page,
      transactions: result.rows.map((item) => ({
        ...item,
        amount: item.amount.toString(),
        balanceAfter: item.balanceAfter.toString(),
      })),
    };
  }
}
