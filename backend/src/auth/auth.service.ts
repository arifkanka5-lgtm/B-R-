import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { JwtService } from '@nestjs/jwt';
import { randomUUID } from 'node:crypto';
import { db } from '../prisma/db.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';

@Injectable()
export class AuthService {
  constructor(private readonly jwtService: JwtService) {}
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
    };
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
