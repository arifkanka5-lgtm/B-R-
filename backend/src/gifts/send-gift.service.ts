import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { pgPool } from '../prisma/pg-pool.js';

@Injectable()
export class SendGiftService {
  async send(
    senderPublicId: string,
    receiverPublicId: string,
    giftCode: string,
    quantity: number,
    requestId: string,
    roomPublicId: string,
  ) {
    if (!Number.isSafeInteger(quantity) || quantity < 1 || quantity > 100) {
      throw new BadRequestException('Gecersiz hediye miktari.');
    }

    if (!/^[a-zA-Z0-9_-]{8,100}$/.test(requestId)) {
      throw new BadRequestException('Gecersiz istek kimligi.');
    }

    if (typeof roomPublicId !== 'string' || !roomPublicId) {
      throw new BadRequestException('Oda kimligi gerekli.');
    }

    const client = await pgPool.connect();

    try {
      await client.query('BEGIN');

      // Aynı istek kimliğini eşzamanlı işlemlerde de koru.
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`,
        [`GIFT:${senderPublicId}:${requestId}`],
      );

      const previous = await client.query(
        `SELECT id, "senderId", "receiverId", "giftId",
                quantity, "totalCoins", "roomId"
         FROM "GiftTransaction"
         WHERE "requestId" = $1 AND "senderId" = (
           SELECT id FROM "User" WHERE "publicId" = $2
         )`,
        [requestId, senderPublicId],
      );

      if (previous.rowCount) {
        const old = previous.rows[0];

        const match = await client.query(
          `SELECT 1
           FROM "User" u
           JOIN "Gift" g ON g.id = $2
           WHERE u."publicId" = $1 AND u.id = $3
             AND g.code = $4`,
          [receiverPublicId, old.giftId, old.receiverId, giftCode],
        );

        const previousRoom = await client.query(
          `SELECT id FROM "Room" WHERE "publicId" = $1`,
          [roomPublicId],
        );

        if (
          !match.rowCount ||
          old.quantity !== quantity ||
          !previousRoom.rowCount ||
          old.roomId !== previousRoom.rows[0].id
        ) {
          throw new ConflictException('Istek kimligi farkli islemde kullanilmis.');
        }

        await client.query('COMMIT');
        return {
          transactionId: old.id.toString(),
          totalCoins: old.totalCoins.toString(),
          status: 'ALREADY_PROCESSED',
        };
      }

      const users = await client.query(
        `SELECT id, "publicId"
         FROM "User"
         WHERE "publicId" = ANY($1::text[])`,
        [[senderPublicId, receiverPublicId]],
      );

      const sender = users.rows.find((u) => u.publicId === senderPublicId);
      const receiver = users.rows.find((u) => u.publicId === receiverPublicId);

      if (!sender) throw new UnauthorizedException('Gonderen bulunamadi.');
      if (!receiver) throw new NotFoundException('Alici bulunamadi.');

      const roomResult = await client.query(
        `SELECT r.id
         FROM "Room" r
         JOIN "RoomMembership" sm
           ON sm."roomId" = r.id AND sm."userId" = $2
         JOIN "RoomMembership" rm
           ON rm."roomId" = r.id AND rm."userId" = $3
         WHERE r."publicId" = $1
           AND r."isActive" = TRUE
         LIMIT 1`,
        [roomPublicId, sender.id, receiver.id],
      );

      if (!roomResult.rowCount) {
        throw new BadRequestException(
          'Gonderici veya alici aktif oda uyesi degil.',
        );
      }

      const roomId = roomResult.rows[0].id;

      const giftResult = await client.query(
        `SELECT id, name, "priceCoins"
         FROM "Gift"
         WHERE code = $1 AND "isActive" = TRUE`,
        [giftCode],
      );

      if (!giftResult.rowCount) {
        throw new NotFoundException('Hediye bulunamadi.');
      }

      const gift = giftResult.rows[0];
      const total = BigInt(gift.priceCoins) * BigInt(quantity);

      const wallet = await client.query(
        `UPDATE "Wallet"
         SET balance = balance - $1,
             "updatedAt" = NOW()
         WHERE "userId" = $2
           AND balance >= $1
         RETURNING id, balance`,
        [total.toString(), sender.id],
      );

      if (!wallet.rowCount) {
        throw new BadRequestException('Yetersiz coin bakiyesi.');
      }

      const tx = await client.query(
        `INSERT INTO "GiftTransaction"
         ("senderId", "receiverId", "giftId",
          quantity, "totalCoins", "requestId", "roomId")
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id`,
        [
          sender.id,
          receiver.id,
          gift.id,
          quantity,
          total.toString(),
          requestId,
          roomId,
        ],
      );

      await client.query(
        `INSERT INTO "CoinTransaction"
         ("walletId", "userId", type, amount,
          "balanceAfter", description, "referenceId")
         VALUES ($1, $2, 'GIFT_SEND', $3, $4, $5, $6)`,
        [
          wallet.rows[0].id,
          sender.id,
          total.toString(),
          wallet.rows[0].balance,
          `Hediye: ${gift.name} x${quantity}`,
          `GIFT_SEND_${tx.rows[0].id}`,
        ],
      );

      await client.query('COMMIT');

      return {
        transactionId: tx.rows[0].id.toString(),
        giftCode,
        roomPublicId,
        senderPublicId,
        receiverPublicId,
        quantity,
        totalCoins: total.toString(),
        remainingBalance: wallet.rows[0].balance.toString(),
        status: 'SUCCESS',
      };
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }
}
