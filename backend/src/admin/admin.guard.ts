import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { getPlatformRole } from '../auth/platform-roles.js';
import { pgPool } from '../prisma/pg-pool.js';

@Injectable()
export class AdminGuard implements CanActivate {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{user?: {sub?: string}}>();
    const publicId = request.user?.sub;
    if (!publicId) throw new UnauthorizedException('Oturum gerekli.');
    if (getPlatformRole(publicId) !== 'SUPER_ADMIN') throw new ForbiddenException('SUPER_ADMIN yetkisi gerekli.');
    const result = await pgPool.query<{isActive:boolean}>(
      'SELECT "isActive" FROM "User" WHERE "publicId" = $1 LIMIT 1', [publicId],
    );
    if (!result.rows[0]?.isActive) throw new ForbiddenException('Hesap pasif.');
    return true;
  }
}
