import { Module } from '@nestjs/common';
import { RoomsModule } from '../rooms/rooms.module.js';
import { SendGiftController } from './send-gift.controller.js';
import { SendGiftService } from './send-gift.service.js';
import { AuthModule } from '../auth/auth.module.js';
import { GiftsController } from './gifts.controller.js';
import { GiftsService } from './gifts.service.js';

@Module({
  imports: [AuthModule, RoomsModule],
  controllers: [GiftsController, SendGiftController],
  providers: [GiftsService, SendGiftService],
  exports: [GiftsService],
})
export class GiftsModule {}
