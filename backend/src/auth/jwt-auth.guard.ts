import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authorization = request.headers.authorization;
    const token = typeof authorization === 'string'
      ? /^Bearer (.+)$/i.exec(authorization)?.[1]
      : undefined;

    if (!token) {
      throw new UnauthorizedException('Giris yapmaniz gerekiyor.');
    }

    try {
      request.user = await this.jwtService.verifyAsync(token);
      return true;
    } catch {
      throw new UnauthorizedException('Gecersiz veya suresi dolmus token.');
    }
  }
}
