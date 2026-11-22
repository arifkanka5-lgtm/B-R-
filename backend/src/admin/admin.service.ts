import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { pgPool } from '../prisma/pg-pool.js';
import { getPlatformRole } from '../auth/platform-roles.js';

@Injectable()
export class AdminService {
  private auditReady: Promise<void> | null = null;
  private async ensureAudit() {
    if (!this.auditReady) {
      this.auditReady = pgPool.query(`
        CREATE TABLE IF NOT EXISTS "BoruAdminAudit" (
          id BIGSERIAL PRIMARY KEY,
          "actorPublicId" TEXT NOT NULL,
          action TEXT NOT NULL,
          "targetPublicId" TEXT NOT NULL,
          "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `).then(() => undefined).catch(e => { this.auditReady = null; throw e; });
    }
    await this.auditReady;
  }
  private limit(value?: string) {
    const n = Number(value ?? '30');
    if (!Number.isInteger(n) || n < 1 || n > 100) throw new BadRequestException('limit 1-100 arasi olmali');
    return n;
  }
  private offset(value?: string) {
    const n = Number(value ?? '0');
    if (!Number.isSafeInteger(n) || n < 0 || n > 1000000) throw new BadRequestException('offset gecersiz');
    return n;
  }
  async stats() {
    const [users, rooms, activeUsers, activeRooms] = await Promise.all([
      pgPool.query<{count:number}>('SELECT COUNT(*)::int AS count FROM "User"'),
      pgPool.query<{count:number}>('SELECT COUNT(*)::int AS count FROM "Room"'),
      pgPool.query<{count:number}>('SELECT COUNT(*)::int AS count FROM "User" WHERE "isActive" = true'),
      pgPool.query<{count:number}>('SELECT COUNT(*)::int AS count FROM "Room" WHERE "isActive" = true'),
    ]);
    return {users:users.rows[0].count, rooms:rooms.rows[0].count, activeUsers:activeUsers.rows[0].count, activeRooms:activeRooms.rows[0].count};
  }
  async users(limit?:string, offset?:string) {
    const result = await pgPool.query<{publicId:string;name:string|null;username:string|null;level:number;isActive:boolean;createdAt:Date}>(
      `SELECT "publicId", name, username, level, "isActive", "createdAt" FROM "User" ORDER BY id DESC LIMIT $1 OFFSET $2`,
      [this.limit(limit),this.offset(offset)],
    );
    return result.rows.map(u=>({...u,platformRole:getPlatformRole(u.publicId)}));
  }
  async rooms(limit?:string,offset?:string) {
    const result = await pgPool.query(
      `SELECT r."publicId", r.name, r."isActive", r."createdAt", u."publicId" AS "ownerPublicId"
       FROM "Room" r JOIN "User" u ON u.id = r."ownerId" ORDER BY r.id DESC LIMIT $1 OFFSET $2`,
      [this.limit(limit),this.offset(offset)],
    );
    return result.rows;
  }
  async setUserActive(actor:string,target:string,active:boolean) {
    if (actor === target) throw new ConflictException('Kendi hesabinizi kapatamazsiniz.');
    if (getPlatformRole(target) === 'SUPER_ADMIN') throw new ConflictException('SUPER_ADMIN hesaplari bu API ile degistirilemez.');
    await this.ensureAudit();
    const client = await pgPool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query<{publicId:string;isActive:boolean}>(
        'UPDATE "User" SET "isActive" = $1, "updatedAt" = NOW() WHERE "publicId" = $2 RETURNING "publicId", "isActive"',
        [active,target],
      );
      if (!result.rows.length) throw new NotFoundException('Kullanici bulunamadi.');
      await client.query('INSERT INTO "BoruAdminAudit" ("actorPublicId", action, "targetPublicId") VALUES ($1,$2,$3)',
        [actor,active?'USER_ACTIVATE':'USER_DEACTIVATE',target]);
      await client.query('COMMIT');
      return result.rows[0];
    } catch(e) { await client.query('ROLLBACK'); throw e; } finally {client.release();}
  }
  async setRoomActive(actor:string,target:string,active:boolean) {
    await this.ensureAudit();
    const client = await pgPool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query<{publicId:string;isActive:boolean}>(
        'UPDATE "Room" SET "isActive" = $1 WHERE "publicId" = $2 RETURNING "publicId", "isActive"',
        [active,target],
      );
      if (!result.rows.length) throw new NotFoundException('Oda bulunamadi.');
      await client.query('INSERT INTO "BoruAdminAudit" ("actorPublicId", action, "targetPublicId") VALUES ($1,$2,$3)',
        [actor,active?'ROOM_ACTIVATE':'ROOM_DEACTIVATE',target]);
      await client.query('COMMIT');
      return result.rows[0];
    } catch(e) { await client.query('ROLLBACK'); throw e; } finally {client.release();}
  }
  async audit(limit?:string,offset?:string) {
    await this.ensureAudit();
    const result = await pgPool.query(
      'SELECT id, "actorPublicId", action, "targetPublicId", "createdAt" FROM "BoruAdminAudit" ORDER BY id DESC LIMIT $1 OFFSET $2',
      [this.limit(limit),this.offset(offset)],
    );
    return result.rows;
  }
}
