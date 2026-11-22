import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { getPlatformRole } from '../auth/platform-roles.js';
import type { Server, Socket } from 'socket.io';
import { pgPool } from '../prisma/pg-pool.js';
import { RoomsService } from './rooms.service.js';

@WebSocketGateway({
  namespace: '/rooms',
  cors: { origin: '*' },
})
@Injectable()
export class RoomsGateway implements OnGatewayConnection {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly roomsService: RoomsService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token;

      if (typeof token !== 'string' || !token) {
        client.disconnect(true);
        return;
      }

      const payload = await this.jwtService.verifyAsync<{ sub: string }>(token);

      if (!payload.sub) {
        client.disconnect(true);
        return;
      }

      client.data.userPublicId = payload.sub;
    } catch {
      client.disconnect(true);
    }
  }

  @SubscribeMessage('room:join')
  async joinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomPublicId?: string },
  ) {
    const userPublicId = client.data.userPublicId;
    const roomPublicId = data?.roomPublicId;

    if (!userPublicId || typeof roomPublicId !== 'string' || !roomPublicId) {
      client.emit('room:error', { message: 'Gecersiz oda istegi.' });
      return;
    }

    const membership = await pgPool.query(
      `SELECT 1
       FROM "RoomMembership" m
       JOIN "Room" r ON r.id = m."roomId"
       JOIN "User" u ON u.id = m."userId"
       WHERE r."publicId" = $1
         AND u."publicId" = $2
         AND r."isActive" = true
         AND u."isActive" = true
       LIMIT 1`,
      [roomPublicId, userPublicId],
    );

    if (!membership.rowCount) {
      client.emit('room:error', {
        message: 'Bu odaya katilma yetkiniz yok.',
      });
      client.disconnect(true);
      return;
    }

    const channel = this.channel(roomPublicId);
    await client.join(channel);

    const seats = await this.roomsService.listRoomSeats(roomPublicId);

    client.emit('room:seats', seats);

    return { joined: true };
  }

  // Metin sohbeti: yalnızca odaya katılmış ve hâlâ aktif üyeler mesaj gönderebilir.
  // Mesaj geçmişi bu sürümde kalıcı değildir.
  @SubscribeMessage('room:message')
  async roomMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomPublicId?: string; text?: string },
  ) {
    const userPublicId = client.data.userPublicId as string | undefined;
    const roomPublicId = data?.roomPublicId;
    const text = typeof data?.text === 'string' ? data.text.trim() : '';

    if (!userPublicId || typeof roomPublicId !== 'string' ||
        !client.rooms.has(this.channel(roomPublicId)) ||
        text.length === 0 || text.length > 300) {
      client.emit('room:error', { message: 'Geçersiz sohbet mesajı veya oda yetkisi.' });
      return;
    }

    const now = Date.now();
    const previous = (client.data.lastRoomMessageAt as number | undefined) ?? 0;
    if (now - previous < 1000) {
      client.emit('room:error', { message: 'Mesaj göndermek için biraz bekleyin.' });
      return;
    }
    client.data.lastRoomMessageAt = now;

    try {
      const result = await pgPool.query<{
        senderPublicId: string;
        senderName: string;
        senderAvatarUrl: string | null;
        roomRole: string;
      }>(
        `SELECT u."publicId" AS "senderPublicId",
                COALESCE(NULLIF(u.name, ''), NULLIF(u.username, ''), 'Kullanıcı') AS "senderName",
                u."avatarUrl" AS "senderAvatarUrl",
                CASE WHEN r."ownerId" = u.id THEN 'OWNER' ELSE m.role END AS "roomRole"
         FROM "User" u
         JOIN "RoomMembership" m ON m."userId" = u.id
         JOIN "Room" r ON r.id = m."roomId"
         WHERE u."publicId" = $1 AND r."publicId" = $2
           AND u."isActive" = true AND r."isActive" = true
         LIMIT 1`,
        [userPublicId, roomPublicId],
      );
      const sender = result.rows[0];
      if (!sender) {
        client.emit('room:error', { message: 'Sohbet için oda üyeliğiniz bulunamadı.' });
        return;
      }

      this.server.to(this.channel(roomPublicId)).emit('room:message', {
        id: randomUUID(),
        roomPublicId,
        senderPublicId: sender.senderPublicId,
        senderName: sender.senderName,
        senderAvatarUrl: sender.senderAvatarUrl,
        platformRole: getPlatformRole(sender.senderPublicId),
        roomRole: sender.roomRole,
        text,
        sentAt: new Date().toISOString(),
      });
    } catch {
      client.emit('room:error', { message: 'Mesaj gönderilemedi. Tekrar deneyin.' });
    }
  }

  async broadcastRoomSeats(roomPublicId: string) {
    const seats = await this.roomsService.listRoomSeats(roomPublicId);

    this.server
      .to(this.channel(roomPublicId))
      .emit('room:seats', seats);
  }

  broadcastGift(data: {
    roomPublicId: string;
    transactionId: string;
    senderPublicId: string;
    receiverPublicId: string;
    giftCode: string;
    quantity: number;
    totalCoins: string;
  }) {
    this.server
      .to(this.channel(data.roomPublicId))
      .emit('gift:received', data);
  }

  private channel(roomPublicId: string) {
    return `room:${roomPublicId}`;
  }
}
