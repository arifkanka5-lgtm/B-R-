import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { RoomsService } from './rooms.service.js';
import { RoomsController } from './rooms.controller.js';
import { RoomsGateway } from './rooms.gateway.js';

@Module({
  imports: [AuthModule],
  providers: [RoomsService, RoomsGateway],
  controllers: [RoomsController],
  exports: [RoomsGateway],
})
export class RoomsModule {}
