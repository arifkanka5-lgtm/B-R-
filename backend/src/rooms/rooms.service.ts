import { Injectable, UnauthorizedException, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import * as argon2 from 'argon2';
import { db } from '../prisma/db.js';
import { pgPool } from '../prisma/pg-pool.js';
import { JoinRoomDto } from './dto/join-room.dto.js';
import { CreateRoomDto } from './dto/create-room.dto.js';
import { AssignRoomRoleDto } from './dto/assign-room-role.dto.js';
import { KickRoomMemberDto } from './dto/kick-room-member.dto.js';
import { TransferRoomOwnerDto } from './dto/transfer-room-owner.dto.js';
import { getPlatformRole } from '../auth/platform-roles.js';

@Injectable()
export class RoomsService {

  async createRoom(userPublicId: string, dto: CreateRoomDto) {
    const passwordHash = dto.password
      ? await argon2.hash(dto.password)
      : null;

    const client = await pgPool.connect();

    try {
      await client.query('BEGIN');

      const userResult = await client.query(
        'SELECT id, "isActive" FROM "User" WHERE "publicId" = $1',
        [userPublicId],
      );

      const user = userResult.rows[0];

      if (!user || !user.isActive) {
        throw new UnauthorizedException('Kullanici bulunamadi.');
      }

      const publicId = randomUUID();
      const name = dto.name.trim();
      const description = dto.description ?? null;
      const capacity = dto.capacity ?? 20;
      const isPrivate = dto.isPrivate ?? Boolean(dto.password);

      const roomResult = await client.query(
        `INSERT INTO "Room"
          ("publicId", name, description, "ownerId", capacity,
           "isPrivate", "passwordHash", "isActive", "updatedAt")
         VALUES ($1, $2, $3, $4, $5, $6, $7, true, NOW())
         RETURNING id, "publicId", name, description, "ownerId",
                   capacity, "isPrivate", "isActive"`,
        [
          publicId,
          name,
          description,
          user.id,
          capacity,
          isPrivate,
          passwordHash,
        ],
      );

      const room = roomResult.rows[0];

      await client.query(
        `INSERT INTO "RoomMembership" ("roomId", "userId", role)
         VALUES ($1, $2, 'OWNER')`,
        [room.id, user.id],
      );

      await client.query('COMMIT');

      return room;
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async listRooms() {
    const rooms = await db.orm.public.Room
      .where({ isActive: true })
      .select(
        'id',
        'publicId',
        'name',
        'description',
        'ownerId',
        'capacity',
        'isPrivate',
        'isActive',
      )
      .all();

    return rooms;
  }


  async joinRoom(userPublicId: string, roomPublicId: string, dto: JoinRoomDto) {
    const client = await pgPool.connect();

    try {
      await client.query('BEGIN');

      const userResult = await client.query(
        'SELECT id, "isActive" FROM "User" WHERE "publicId" = $1',
        [userPublicId],
      );

      const user = userResult.rows[0];

      if (!user || !user.isActive) {
        throw new UnauthorizedException('Kullanici bulunamadi veya pasif.');
      }

      const roomResult = await client.query(
        `SELECT id, "publicId", name, capacity, "isPrivate",
                "passwordHash", "isActive"
         FROM "Room"
         WHERE "publicId" = $1
         FOR UPDATE`,
        [roomPublicId],
      );

      const room = roomResult.rows[0];

      if (!room || !room.isActive) {
        throw new NotFoundException('Oda bulunamadi veya aktif degil.');
      }

      if (room.isPrivate) {
        if (
          !room.passwordHash ||
          !dto.password ||
          !(await argon2.verify(room.passwordHash, dto.password))
        ) {
          throw new UnauthorizedException('Oda sifresi hatali.');
        }
      }

      const existing = await client.query(
        'SELECT id FROM "RoomMembership" WHERE "roomId" = $1 AND "userId" = $2',
        [room.id, user.id],
      );

      if (existing.rowCount) {
        throw new ConflictException('Bu odanin zaten uyesisiniz.');
      }

      const countResult = await client.query(
        'SELECT COUNT(*)::int AS count FROM "RoomMembership" WHERE "roomId" = $1',
        [room.id],
      );

      if (countResult.rows[0].count >= room.capacity) {
        throw new BadRequestException('Oda kapasitesi dolu.');
      }

      const inserted = await client.query(
        `INSERT INTO "RoomMembership" ("roomId", "userId")
         VALUES ($1, $2)
         RETURNING "joinedAt"`,
        [room.id, user.id],
      );

      const finalCount = await client.query(
        'SELECT COUNT(*)::int AS count FROM "RoomMembership" WHERE "roomId" = $1',
        [room.id],
      );

      await client.query('COMMIT');

      return {
        joined: true,
        roomPublicId: room.publicId,
        roomName: room.name,
        userId: user.id,
        joinedAt: inserted.rows[0].joinedAt,
        memberCount: finalCount.rows[0].count,
        capacity: room.capacity,
      };
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async leaveRoom(userPublicId: string, roomPublicId: string) {
    const user = await db.orm.public.User.where({
      publicId: userPublicId,
    }).first();

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Kullanici bulunamadi veya pasif.');
    }

    const room = await db.orm.public.Room.where({
      publicId: roomPublicId,
    }).first();

    if (!room || !room.isActive) {
      throw new NotFoundException('Oda bulunamadi.');
    }

    if (room.ownerId === user.id) {
      throw new BadRequestException(
        'Oda sahibi ayrilmadan once sahipligi devretmelidir.',
      );
    }

    const membership = await db.orm.public.RoomMembership.where({
      roomId: room.id,
      userId: user.id,
    }).first();

    if (!membership) {
      throw new NotFoundException('Bu odanin uyesi degilsiniz.');
    }

    await db.orm.public.RoomMembership
      .where({ roomId: room.id, userId: user.id })
      .delete();

    const remaining = await db.orm.public.RoomMembership
      .where({ roomId: room.id })
      .all();

    return {
      left: true,
      roomPublicId: room.publicId,
      roomName: room.name,
      memberCount: remaining.length,
    };
  }



  async listRoomSeats(roomPublicId: string) {
    const room = await pgPool.query(
      `SELECT id, capacity FROM "Room"
       WHERE "publicId" = $1 AND "isActive" = true`,
      [roomPublicId],
    );

    if (!room.rowCount) throw new NotFoundException('Oda bulunamadi.');

    const roomId = room.rows[0].id;

    await pgPool.query(
      `INSERT INTO "RoomSeat" ("roomId", "seatNumber")
       SELECT $1, n FROM generate_series(1, $2) AS n
       ON CONFLICT ("roomId", "seatNumber") DO NOTHING`,
      [roomId, room.rows[0].capacity],
    );

    const result = await pgPool.query(
      `SELECT s."seatNumber", s."userId", s."isLocked",
              u."publicId" AS "userPublicId",
              u.name, u.username, u."avatarUrl",
              CASE WHEN r."ownerId" = u.id THEN 'OWNER' ELSE m.role END AS "roomRole"
       FROM "RoomSeat" s
       JOIN "Room" r ON r.id = s."roomId"
       LEFT JOIN "User" u ON u.id = s."userId"
       LEFT JOIN "RoomMembership" m ON m."roomId" = s."roomId" AND m."userId" = s."userId"
       WHERE s."roomId" = $1
       ORDER BY s."seatNumber"`,
      [roomId],
    );

    return {
      roomPublicId,
      seats: result.rows.map((seat) => ({
        ...seat,
        platformRole: seat.userPublicId ? getPlatformRole(seat.userPublicId) : 'USER',
      })),
    };
  }

  async sitOnSeat(userPublicId: string, roomPublicId: string, seatNumber: number) {
    const client = await pgPool.connect();

    try {
      await client.query('BEGIN');

      const roomResult = await client.query(
        `SELECT id, capacity FROM "Room"
         WHERE "publicId" = $1 AND "isActive" = true FOR UPDATE`,
        [roomPublicId],
      );
      const room = roomResult.rows[0];

      if (!room) throw new NotFoundException('Oda bulunamadi.');

      if (seatNumber < 1 || seatNumber > room.capacity) {
        throw new BadRequestException('Gecersiz koltuk numarasi.');
      }

      const userResult = await client.query(
        `SELECT id FROM "User"
         WHERE "publicId" = $1 AND "isActive" = true`,
        [userPublicId],
      );
      const user = userResult.rows[0];

      if (!user) throw new UnauthorizedException('Kullanici bulunamadi.');

      const membership = await client.query(
        `SELECT id FROM "RoomMembership"
         WHERE "roomId" = $1 AND "userId" = $2`,
        [room.id, user.id],
      );

      if (!membership.rowCount) {
        throw new BadRequestException('Once odaya katilmalisiniz.');
      }

      await client.query(
        `INSERT INTO "RoomSeat" ("roomId", "seatNumber")
         SELECT $1, n FROM generate_series(1, $2) AS n
         ON CONFLICT ("roomId", "seatNumber") DO NOTHING`,
        [room.id, room.capacity],
      );

      const seatResult = await client.query(
        `SELECT id, "userId", "isLocked"
         FROM "RoomSeat"
         WHERE "roomId" = $1 AND "seatNumber" = $2
         FOR UPDATE`,
        [room.id, seatNumber],
      );
      const seat = seatResult.rows[0];

      if (!seat) throw new NotFoundException('Koltuk bulunamadi.');
      if (seat.isLocked) throw new ConflictException('Koltuk kilitli.');
      if (seat.userId !== null && seat.userId !== user.id) {
        throw new ConflictException('Koltuk baska bir kullaniciya ait.');
      }

      await client.query(
        `UPDATE "RoomSeat" SET "userId" = NULL
         WHERE "roomId" = $1 AND "userId" = $2 AND id <> $3`,
        [room.id, user.id, seat.id],
      );

      await client.query(
        `UPDATE "RoomSeat" SET "userId" = $1 WHERE id = $2`,
        [user.id, seat.id],
      );

      await client.query('COMMIT');

      return { seated: true, roomPublicId, seatNumber };
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async leaveSeat(userPublicId: string, roomPublicId: string) {
    const result = await pgPool.query(
      `UPDATE "RoomSeat" s
       SET "userId" = NULL
       FROM "Room" r, "User" u
       WHERE s."roomId" = r.id
         AND s."userId" = u.id
         AND r."publicId" = $1
         AND u."publicId" = $2
       RETURNING s."seatNumber"`,
      [roomPublicId, userPublicId],
    );

    return {
      leftSeat: result.rowCount === 1,
      roomPublicId,
      seatNumber: result.rows[0]?.seatNumber ?? null,
    };
  }

  async setSeatLock(
    actorPublicId: string,
    roomPublicId: string,
    seatNumber: number,
    isLocked: boolean,
  ) {
    const client = await pgPool.connect();

    try {
      await client.query('BEGIN');

      const roomResult = await client.query(
        `SELECT id, "ownerId", capacity FROM "Room"
         WHERE "publicId" = $1 AND "isActive" = true FOR UPDATE`,
        [roomPublicId],
      );
      const room = roomResult.rows[0];

      if (!room) throw new NotFoundException('Oda bulunamadi.');

      const actorResult = await client.query(
        `SELECT id FROM "User"
         WHERE "publicId" = $1 AND "isActive" = true`,
        [actorPublicId],
      );
      const actor = actorResult.rows[0];

      if (!actor) throw new UnauthorizedException('Kullanici bulunamadi.');

      const membership = await client.query(
        `SELECT role FROM "RoomMembership"
         WHERE "roomId" = $1 AND "userId" = $2`,
        [room.id, actor.id],
      );

      const role = membership.rows[0]?.role;
      if (actor.id !== room.ownerId &&
          !['ADMIN', 'MODERATOR'].includes(role)) {
        throw new UnauthorizedException('Koltuk yonetim yetkiniz yok.');
      }

      const seatResult = await client.query(
        `SELECT id, "userId" FROM "RoomSeat"
         WHERE "roomId" = $1 AND "seatNumber" = $2 FOR UPDATE`,
        [room.id, seatNumber],
      );
      const seat = seatResult.rows[0];

      if (!seat) throw new NotFoundException('Koltuk bulunamadi.');

      if (isLocked && seat.userId !== null) {
        throw new ConflictException('Dolu koltuk kilitlenemez.');
      }

      await client.query(
        `UPDATE "RoomSeat" SET "isLocked" = $1 WHERE id = $2`,
        [isLocked, seat.id],
      );

      await client.query('COMMIT');

      return { updated: true, seatNumber, isLocked };
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async listRoomMembers(roomPublicId: string) {
    const room = await db.orm.public.Room.where({
      publicId: roomPublicId,
    }).first();

    if (!room || !room.isActive) {
      throw new NotFoundException('Oda bulunamadi.');
    }

    const memberships = await db.orm.public.RoomMembership
      .where({ roomId: room.id })
      .all();

    const members = await Promise.all(
      memberships.map(async (membership) => {
        const user = await db.orm.public.User.where({
          id: membership.userId,
        }).first();

        if (!user || !user.isActive) return null;

        return {
          publicId: user.publicId,
          username: user.username,
          name: user.name,
          avatarUrl: user.avatarUrl,
          level: user.level,
          joinedAt: membership.joinedAt,
          role: user.id === room.ownerId ? 'OWNER' : membership.role,
          platformRole: getPlatformRole(user.publicId),
          isOwner: user.id === room.ownerId,
        };
      }),
    );

    const activeMembers = members.filter((member) => member !== null);

    return {
      roomPublicId: room.publicId,
      roomName: room.name,
      memberCount: activeMembers.length,
      capacity: room.capacity,
      members: activeMembers,
    };
  }

  async transferRoomOwner(
    currentOwnerPublicId: string,
    roomPublicId: string,
    dto: TransferRoomOwnerDto,
  ) {
    const client = await pgPool.connect();

    try {
      await client.query('BEGIN');

      const roomResult = await client.query(
        'SELECT id, "publicId", "ownerId", name FROM "Room" WHERE "publicId" = $1 AND "isActive" = true FOR UPDATE',
        [roomPublicId],
      );

      const room = roomResult.rows[0];

      if (!room) {
        throw new NotFoundException('Oda bulunamadi.');
      }

      const ownerResult = await client.query(
        'SELECT id FROM "User" WHERE "publicId" = $1 AND "isActive" = true',
        [currentOwnerPublicId],
      );

      const owner = ownerResult.rows[0];

      if (!owner || owner.id !== room.ownerId) {
        throw new UnauthorizedException('Bu islem sadece oda sahibine aciktir.');
      }

      const newOwnerResult = await client.query(
        'SELECT id FROM "User" WHERE "publicId" = $1 AND "isActive" = true',
        [dto.newOwnerPublicId],
      );

      const newOwner = newOwnerResult.rows[0];

      if (!newOwner) {
        throw new NotFoundException('Yeni sahip bulunamadi.');
      }

      if (newOwner.id === owner.id) {
        throw new BadRequestException('Mevcut sahip zaten sizsiniz.');
      }

      const membership = await client.query(
        'SELECT id FROM "RoomMembership" WHERE "roomId" = $1 AND "userId" = $2',
        [room.id, newOwner.id],
      );

      if (!membership.rowCount) {
        throw new BadRequestException('Yeni sahip once odanin uyesi olmalidir.');
      }

      await client.query(
        'UPDATE "Room" SET "ownerId" = $1, "updatedAt" = NOW() WHERE id = $2',
        [newOwner.id, room.id],
      );

      await client.query(
        'UPDATE "RoomMembership" SET role = $1 WHERE "roomId" = $2 AND "userId" = $3',
        ['MEMBER', room.id, owner.id],
      );

      await client.query(
        'UPDATE "RoomMembership" SET role = $1 WHERE "roomId" = $2 AND "userId" = $3',
        ['OWNER', room.id, newOwner.id],
      );

      await client.query('COMMIT');

      return {
        transferred: true,
        roomPublicId: room.publicId,
        roomName: room.name,
        previousOwnerId: owner.id,
        newOwnerId: newOwner.id,
      };
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }


  async assignRoomRole(
    ownerPublicId: string,
    roomPublicId: string,
    dto: AssignRoomRoleDto,
  ) {
    const client = await pgPool.connect();

    try {
      await client.query('BEGIN');

      const roomResult = await client.query(
        'SELECT id, "ownerId", name FROM "Room" WHERE "publicId" = $1 AND "isActive" = true FOR UPDATE',
        [roomPublicId],
      );

      const room = roomResult.rows[0];

      if (!room) {
        throw new NotFoundException('Oda bulunamadi.');
      }

      const ownerResult = await client.query(
        'SELECT id FROM "User" WHERE "publicId" = $1 AND "isActive" = true',
        [ownerPublicId],
      );

      const owner = ownerResult.rows[0];

      if (!owner || owner.id !== room.ownerId) {
        throw new UnauthorizedException('Sadece oda sahibi rol atayabilir.');
      }

      const targetResult = await client.query(
        'SELECT id FROM "User" WHERE "publicId" = $1 AND "isActive" = true',
        [dto.userPublicId],
      );

      const target = targetResult.rows[0];

      if (!target) {
        throw new NotFoundException('Kullanici bulunamadi.');
      }

      if (target.id === owner.id) {
        throw new BadRequestException('Oda sahibinin rolu degistirilemez.');
      }

      const membership = await client.query(
        'SELECT id FROM "RoomMembership" WHERE "roomId" = $1 AND "userId" = $2 FOR UPDATE',
        [room.id, target.id],
      );

      if (!membership.rowCount) {
        throw new BadRequestException('Kullanici odanin uyesi degil.');
      }

      await client.query(
        'UPDATE "RoomMembership" SET role = $1 WHERE "roomId" = $2 AND "userId" = $3',
        [dto.role, room.id, target.id],
      );

      await client.query('COMMIT');

      return {
        assigned: true,
        roomName: room.name,
        userPublicId: dto.userPublicId,
        role: dto.role,
      };
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }


  async kickRoomMember(
    actorPublicId: string,
    roomPublicId: string,
    dto: KickRoomMemberDto,
  ) {
    const client = await pgPool.connect();

    try {
      await client.query('BEGIN');

      const roomResult = await client.query(
        'SELECT id, "ownerId", name FROM "Room" WHERE "publicId" = $1 AND "isActive" = true FOR UPDATE',
        [roomPublicId],
      );
      const room = roomResult.rows[0];
      if (!room) {
        throw new NotFoundException('Oda bulunamadi.');
      }

      const usersResult = await client.query(
        'SELECT id, "publicId" FROM "User" WHERE "publicId" = ANY($1::text[]) AND "isActive" = true',
        [[actorPublicId, dto.userPublicId]],
      );

      const actor = usersResult.rows.find(
        (u) => u.publicId === actorPublicId,
      );
      const target = usersResult.rows.find(
        (u) => u.publicId === dto.userPublicId,
      );

      if (!actor) {
        throw new UnauthorizedException('Yetkisiz kullanici.');
      }
      if (!target) {
        throw new NotFoundException('Hedef kullanici bulunamadi.');
      }
      if (target.id === room.ownerId) {
        throw new BadRequestException('Oda sahibi cikarilamaz.');
      }
      if (actor.id === target.id) {
        throw new BadRequestException('Kendinizi KICK ile cikaramazsiniz.');
      }

      const memberships = await client.query(
        'SELECT "userId", role FROM "RoomMembership" WHERE "roomId" = $1 AND "userId" = ANY($2::int[]) FOR UPDATE',
        [room.id, [actor.id, target.id]],
      );

      const actorMember = memberships.rows.find(
        (m) => m.userId === actor.id,
      );
      const targetMember = memberships.rows.find(
        (m) => m.userId === target.id,
      );

      if (!actorMember) {
        throw new UnauthorizedException('Odanin uyesi degilsiniz.');
      }
      if (!targetMember) {
        throw new NotFoundException('Hedef kullanici odada degil.');
      }

      const actorRole =
        actor.id === room.ownerId ? 'OWNER' : actorMember.role;
      const targetRole = targetMember.role;

      const rank: Record<string, number> = {
        OWNER: 4,
        ADMIN: 3,
        MODERATOR: 2,
        MEMBER: 1,
      };

      if (
        !rank[actorRole] ||
        !rank[targetRole] ||
        rank[actorRole] <= rank[targetRole]
      ) {
        throw new UnauthorizedException('KICK yetkiniz bulunmuyor.');
      }

      await client.query(
        'DELETE FROM "RoomMembership" WHERE "roomId" = $1 AND "userId" = $2',
        [room.id, target.id],
      );

      await client.query('COMMIT');

      return {
        kicked: true,
        roomName: room.name,
        userPublicId: dto.userPublicId,
        kickedByRole: actorRole,
      };
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }


}
