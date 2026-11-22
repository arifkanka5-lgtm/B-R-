import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { pgPool } from '../prisma/pg-pool.js';

const PACKAGES = [
  { id: 'coins_100k', coins: 100000, priceKurus: 350 },
  { id: 'coins_500k', coins: 500000, priceKurus: 1750 },
  { id: 'coins_1m', coins: 1000000, priceKurus: 3500 },
  { id: 'coins_5m', coins: 5000000, priceKurus: 17500 },
];

@Injectable()
export class ManualPaymentService {
  getPackages() {
    return PACKAGES.map((p) => ({
      id: p.id,
      coins: p.coins,
      priceKurus: p.priceKurus,
      currency: 'TRY',
    }));
  }

  async createRequest(
    userPublicId: string,
    packageId: string,
    paymentReference?: string,
  ) {
    const selected = PACKAGES.find((p) => p.id === packageId);

    if (!selected) {
      throw new BadRequestException('Gecersiz coin paketi.');
    }

    if (
      paymentReference !== undefined &&
      (typeof paymentReference !== 'string' ||
        paymentReference.length > 150)
    ) {
      throw new BadRequestException('Gecersiz odeme referansi.');
    }

    const user = await pgPool.query(
      `SELECT id FROM "User" WHERE "publicId" = $1`,
      [userPublicId],
    );

    if (!user.rowCount) {
      throw new UnauthorizedException('Kullanici bulunamadi.');
    }

    const result = await pgPool.query(
      `INSERT INTO "CoinPaymentRequest"
       ("userId", "coinAmount", "priceKurus", "currency",
        "status", "paymentReference")
       VALUES ($1, $2, $3, 'TRY', 'PENDING', $4)
       RETURNING id, "coinAmount", "priceKurus",
                 currency, status, "createdAt"`,
      [
        user.rows[0].id,
        selected.coins,
        selected.priceKurus,
        paymentReference?.trim() || null,
      ],
    );

    const item = result.rows[0];

    return {
      id: item.id.toString(),
      coinAmount: item.coinAmount.toString(),
      priceKurus: item.priceKurus.toString(),
      currency: item.currency,
      status: item.status,
      createdAt: item.createdAt,
    };
  }

  async myRequests(userPublicId: string) {
    const result = await pgPool.query(
      `SELECT id, "coinAmount", "priceKurus",
              currency, status, "createdAt", "reviewedAt"
       FROM "CoinPaymentRequest"
       WHERE "userId" = (
         SELECT id FROM "User" WHERE "publicId" = $1
       )
       ORDER BY "createdAt" DESC, id DESC
       LIMIT 50`,
      [userPublicId],
    );

    return result.rows.map((item) => ({
      ...item,
      id: item.id.toString(),
      coinAmount: item.coinAmount.toString(),
      priceKurus: item.priceKurus.toString(),
    }));
  }
}
