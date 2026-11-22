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
