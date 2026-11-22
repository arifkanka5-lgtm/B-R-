import { Injectable, ServiceUnavailableException, ForbiddenException } from '@nestjs/common';
import { AccessToken, RoomServiceClient } from 'livekit-server-sdk';
import { pgPool } from '../prisma/pg-pool.js';

@Injectable()
export class LivekitService {
  private getConfig() {
    const url = process.env.LIVEKIT_URL;
    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET;

    if (!url || !apiKey || !apiSecret) {
      throw new ServiceUnavailableException(
        'LiveKit sunucu yapilandirmasi eksik.',
      );
    }

    return { url, apiKey, apiSecret };
  }

  async verifyRoomMembership(
    roomPublicId: string,
    userPublicId: string,
  ): Promise<string> {
    const result = await pgPool.query(
      `SELECT u.name
       FROM "User" u
       JOIN "RoomMembership" m ON m."userId" = u.id
       JOIN "Room" r ON r.id = m."roomId"
       WHERE u."publicId" = $1
         AND r."publicId" = $2
         AND u."isActive" = true
         AND r."isActive" = true
       LIMIT 1`,
      [userPublicId, roomPublicId],
    );

    if (result.rowCount !== 1) {
      throw new ForbiddenException(
        'Bu sesli odaya giris yetkiniz bulunmuyor.',
      );
    }

    return result.rows[0].name;
  }

  async createRoomToken(
    roomPublicId: string,
    userPublicId: string,
  ): Promise<string> {
    const displayName = await this.verifyRoomMembership(
      roomPublicId,
      userPublicId,
    );
    const { apiKey, apiSecret } = this.getConfig();

    const token = new AccessToken(apiKey, apiSecret, {
      identity: userPublicId,
      name: displayName,
      ttl: '1h',
    });

    token.addGrant({
      roomJoin: true,
      room: roomPublicId,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    return token.toJwt();
  }

  async removeParticipant(
    roomPublicId: string,
    userPublicId: string,
  ): Promise<void> {
    const { url, apiKey, apiSecret } = this.getConfig();

    const client = new RoomServiceClient(url, apiKey, apiSecret);

    await client.removeParticipant(roomPublicId, userPublicId);
  }
}
