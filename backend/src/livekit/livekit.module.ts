import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { LivekitService } from './livekit.service.js';
import { LivekitController } from './livekit.controller.js';

@Module({
  imports: [AuthModule],
  controllers: [LivekitController],
  providers: [LivekitService],
  exports: [LivekitService],
})
export class LivekitModule {}
