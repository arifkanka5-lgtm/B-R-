import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { pgPool } from '../prisma/pg-pool.js';

@Injectable()
export class GiftsService {
  async findAll(category?: string) {
    const allowed = [
      'ROMANTIC',
      'FUN',
      'ANIMALS',
      'VEHICLES',
      'ROYAL',
      'SVIP',
    ];

    if (category && !allowed.includes(category)) {
      return [];
    }

    const result = await pgPool.query(
      `SELECT id, code, name, "priceCoins",
              category, "imageUrl", "animationUrl"
       FROM "Gift"
       WHERE "isActive" = TRUE
         AND ($1::text IS NULL OR category = $1)
       ORDER BY "priceCoins" ASC, id ASC`,
      [category ?? null],
    );

    return result.rows.map((gift) => ({
      ...gift,
      priceCoins: gift.priceCoins.toString(),
    }));
  }

  async findOne(code: string) {
    const result = await pgPool.query(
      `SELECT id, code, name, "priceCoins",
              category, "imageUrl", "animationUrl"
       FROM "Gift"
       WHERE code = $1 AND "isActive" = TRUE`,
      [code],
    );

    if (!result.rowCount) {
      throw new NotFoundException('Hediye bulunamadi.');
    }

    return {
      ...result.rows[0],
      priceCoins: result.rows[0].priceCoins.toString(),
    };
  }
}
