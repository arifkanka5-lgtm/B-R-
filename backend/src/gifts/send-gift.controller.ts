import {
  Body,
  Controller,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  IsInt,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { SendGiftService } from './send-gift.service.js';
import { RoomsGateway } from '../rooms/rooms.gateway.js';

class SendGiftDto {
  @IsString()
  receiverPublicId!: string;

  @IsString()
  giftCode!: string;

  @IsString()
  roomPublicId!: string;

  @IsInt()
  @Min(1)
  @Max(100)
  quantity!: number;

  @IsString()
  @Matches(/^[a-zA-Z0-9_-]{8,100}$/)
  requestId!: string;
}

@Controller('gifts')
@UseGuards(JwtAuthGuard)
export class SendGiftController {
  constructor(
    private readonly sender: SendGiftService,
    private readonly roomsGateway: RoomsGateway,
  ) {}

  @Post('send')
  async send(
    @Req() req: { user: { sub: string } },
    @Body() dto: SendGiftDto,
  ) {
    const result = await this.sender.send(
      req.user.sub,
      dto.receiverPublicId,
      dto.giftCode,
      dto.quantity,
      dto.requestId,
      dto.roomPublicId,
    );

    if (result.status === 'SUCCESS') {
      this.roomsGateway.broadcastGift({
        roomPublicId: dto.roomPublicId,
        transactionId: result.transactionId,
        senderPublicId: req.user.sub,
        receiverPublicId: dto.receiverPublicId,
        giftCode: dto.giftCode,
        quantity: dto.quantity,
        totalCoins: result.totalCoins,
      });
    }

    return result;
  }
}
