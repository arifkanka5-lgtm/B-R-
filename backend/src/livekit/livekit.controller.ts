import { Controller, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { LivekitService } from './livekit.service.js';

@Controller('livekit')
export class LivekitController {
  constructor(private readonly livekitService: LivekitService) {}

  @UseGuards(JwtAuthGuard)
  @Post('rooms/:roomPublicId/token')
  async createToken(
    @Param('roomPublicId') roomPublicId: string,
    @Req() request: { user: { sub: string } },
  ) {
    const token = await this.livekitService.createRoomToken(
      roomPublicId,
      request.user.sub,
    );
    return { token };
  }
}
