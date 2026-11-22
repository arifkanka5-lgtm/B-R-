import { ConflictException, Injectable, UnauthorizedException, ServiceUnavailableException, NotFoundException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { JwtService } from '@nestjs/jwt';
import { OAuth2Client } from 'google-auth-library';
import { pgPool } from '../prisma/pg-pool.js';
import { randomUUID } from 'node:crypto';
import { db } from '../prisma/db.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
import { getPlatformRole } from './platform-roles.js';

@Injectable()
export class AuthService {
  constructor(private readonly jwtService: JwtService) {}
  private readonly googleOAuthClient = new OAuth2Client();
  private googleIdentityTableReady: Promise<void> | null = null;

  // Geliştirme aşamasında ilk Google isteğinde ayrı kimlik tablosunu hazırlar.
  // Üretime geçerken bunu sürümlü SQL migration olarak yönetmek gerekir.
  private async ensureGoogleIdentityTable(): Promise<void> {
    if (!this.googleIdentityTableReady) {
      this.googleIdentityTableReady = pgPool.query(`
        CREATE TABLE IF NOT EXISTS "BoruGoogleIdentity" (
          "googleSub" TEXT PRIMARY KEY,
          "userId" INTEGER NOT NULL UNIQUE REFERENCES "User"(id) ON DELETE CASCADE,
          "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
      `).then(() => undefined).catch((error: unknown) => {
        this.googleIdentityTableReady = null;
        throw error;
      });
    }
    await this.googleIdentityTableReady;
  }

  async googleLogin(idToken: string) {
    const webClientId = process.env['GOOGLE_WEB_CLIENT_ID']?.trim();
    if (!webClientId) {
      throw new ServiceUnavailableException('Google girişi sunucuda henüz yapılandırılmadı.');
    }

    let payload;
    try {
      const ticket = await this.googleOAuthClient.verifyIdToken({
        idToken,
        audience: webClientId,
      });
      payload = ticket.getPayload();
    } catch {
      throw new UnauthorizedException('Google kimliği doğrulanamadı.');
    }

    if (!payload?.sub || !payload.email || payload.email_verified !== true) {
      throw new UnauthorizedException('Doğrulanmış Google hesabı gerekli.');
    }

    const googleSub = payload.sub;
    const email = payload.email.trim().toLowerCase();
    const name = payload.name?.trim().slice(0, 50) || null;
    const avatarUrl = payload.picture?.slice(0, 2048) || null;
    await this.ensureGoogleIdentityTable();

    type GoogleUser = {
      id: number;
      publicId: string;
      email: string;
      name: string | null;
      isActive: boolean;
    };

    const client = await pgPool.connect();
    let user: GoogleUser | undefined;
    try {
      await client.query('BEGIN');
      const linked = await client.query<GoogleUser>(
        `SELECT u.id, u."publicId", u.email, u.name, u."isActive"
         FROM "BoruGoogleIdentity" g
         JOIN "User" u ON u.id = g."userId"
         WHERE g."googleSub" = $1
         FOR UPDATE OF u`,
        [googleSub],
      );

      if (linked.rows.length) {
        user = linked.rows[0];
      } else {
        // E-posta eşitliği tek başına hesapları birleştirmek için yeterli değildir.
        // Mevcut kullanıcı hesabına otomatik erişim vermek hesap ele geçirme riski taşır.
        const emailExists = await client.query(
          'SELECT id FROM "User" WHERE email = $1 LIMIT 1',
          [email],
        );
        if (emailExists.rows.length) {
          throw new ConflictException(
            'Bu e-posta ile BÖRÜ hesabı mevcut. Güvenlik nedeniyle otomatik bağlanmadı; e-posta ve şifrenizle giriş yapın.',
          );
        }

        const created = await client.query<GoogleUser>(
          `INSERT INTO "User"
             ("publicId", email, name, "passwordHash", "avatarUrl", "createdAt", "updatedAt")
           VALUES ($1, $2, $3, NULL, $4, NOW(), NOW())
           RETURNING id, "publicId", email, name, "isActive"`,
          [randomUUID(), email, name, avatarUrl],
        );
        const newUser = created.rows[0];
        if (!newUser) throw new ServiceUnavailableException('Kullanıcı oluşturulamadı.');
        user = newUser;
        await client.query(
          'INSERT INTO "BoruGoogleIdentity" ("googleSub", "userId") VALUES ($1, $2)',
          [googleSub, newUser.id],
        );
      }

      if (!user?.isActive) {
        throw new UnauthorizedException('Bu BÖRÜ hesabı pasif.');
      }
      await client.query('COMMIT');
    } catch (error: unknown) {
      await client.query('ROLLBACK');
      if ((error as { code?: string }).code === '23505') {
        throw new ConflictException('Hesap eşleştirmesi çakıştı. Tekrar deneyin.');
      }
      throw error;
    } finally {
      client.release();
    }

    if (!user) throw new UnauthorizedException('Google oturumu oluşturulamadı.');
    const accessToken = await this.jwtService.signAsync({
      sub: user.publicId,
      userId: user.id,
    });
    return {
      accessToken,
      tokenType: 'Bearer',
      user: {
        id: user.id,
        publicId: user.publicId,
        email: user.email,
        name: user.name,
      },
    };
  }

  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();
    const existing = await db.orm.public.User.where({ email }).first();

    if (existing) {
      throw new ConflictException('Bu e-posta zaten kayıtlı.');
    }

    const passwordHash = await argon2.hash(dto.password);
    const user = await db.orm.public.User.create({
      email,
      passwordHash,
      publicId: randomUUID(),
      name: dto.name ?? null,
    });

    return {
      id: user.id,
      publicId: user.publicId,
      email: user.email,
      name: user.name,
    };
  }

  async login(dto: LoginDto) {
    const email = dto.email.trim().toLowerCase();
    const user = await db.orm.public.User.where({ email }).first();

    if (!user || !user.passwordHash || !user.isActive ||
        !(await argon2.verify(user.passwordHash, dto.password))) {
      throw new UnauthorizedException('E-posta veya sifre hatali.');
    }

    const accessToken = await this.jwtService.signAsync({
      sub: user.publicId,
      userId: user.id,
    });

    return {
      accessToken,
      tokenType: 'Bearer',
      user: {
        id: user.id,
        publicId: user.publicId,
        email: user.email,
        name: user.name,
      },
    };
  }


  async getProfile(publicId: string) {
    const user = await db.orm.public.User.where({ publicId }).first();

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Kullanici bulunamadi veya pasif.');
    }

    return {
      id: user.id,
      publicId: user.publicId,
      email: user.email,
      name: user.name,
      username: user.username,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      level: user.level,
      platformRole: getPlatformRole(user.publicId),
    };
  }

  // Başkalarının profili: e-posta, bakiye ve özel bilgiler paylaşılmaz.
  async getPublicProfile(publicId: string, roomPublicId?: string) {
    const result = await pgPool.query<{
      publicId: string;
      username: string | null;
      name: string | null;
      avatarUrl: string | null;
      bio: string | null;
      level: number;
    }>(
      `SELECT "publicId", username, name, "avatarUrl", bio, level
       FROM "User" WHERE "publicId" = $1 AND "isActive" = true LIMIT 1`,
      [publicId],
    );
    const user = result.rows[0];
    if (!user) throw new NotFoundException('Kullanıcı profili bulunamadı.');

    let roomRole: string | null = null;
    if (roomPublicId) {
      const membership = await pgPool.query<{ role: string }>(
        `SELECT CASE WHEN r."ownerId" = u.id THEN 'OWNER' ELSE m.role END AS role
         FROM "RoomMembership" m
         JOIN "Room" r ON r.id = m."roomId" AND r."isActive" = true
         JOIN "User" u ON u.id = m."userId"
         WHERE r."publicId" = $1 AND u."publicId" = $2 LIMIT 1`,
        [roomPublicId, publicId],
      );
      roomRole = membership.rows[0]?.role ?? null;
    }

    return { ...user, platformRole: getPlatformRole(publicId), roomRole };
  }

  async updateProfile(publicId: string, dto: UpdateProfileDto) {
    const user = await db.orm.public.User.where({ publicId }).first();

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Kullanici bulunamadi veya pasif.');
    }

    if (dto.username !== undefined && dto.username !== user.username) {
      const existing = await db.orm.public.User.where({
        username: dto.username,
      }).first();

      if (existing) {
        throw new ConflictException('Bu kullanici adi zaten alinmis.');
      }
    }

    const updated = await db.orm.public.User.where({ publicId }).update({
      ...(dto.username !== undefined ? { username: dto.username } : {}),
      ...(dto.name !== undefined ? { name: dto.name } : {}),
      ...(dto.bio !== undefined ? { bio: dto.bio } : {}),
      ...(dto.avatarUrl !== undefined ? { avatarUrl: dto.avatarUrl } : {}),
    });

    return this.getProfile(publicId);
  }

}
