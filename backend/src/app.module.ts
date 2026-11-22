import { Module } from '@nestjs/common';
import { GiftsModule } from './gifts/gifts.module.js';
import { createObserveModule } from '@nestjs/observe';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { RoomsModule } from './rooms/rooms.module.js';
import { LivekitModule } from './livekit/livekit.module.js';
import { WalletModule } from './wallet/wallet.module.js';

export const { ObserveModule, ObserveInstrument } = createObserveModule();

@Module({
  imports: [
    // Distributed tracing, auto-correlated logs, request/job metrics, error
    // telemetry, alarms, and more — out of the box. Sign up at https://observe.nestjs.com,
    // then run `npx @nestjs/observe link` to write your key pair into .env.
    ObserveModule.forRoot({
      appKey: process.env.OBSERVE_APP_KEY ?? 'YOUR_APP_KEY',
      appSecret: process.env.OBSERVE_APP_SECRET ?? 'YOUR_APP_SECRET',
      serviceId: 'backend',
    }),
    AuthModule,
    RoomsModule,
    LivekitModule,
    WalletModule,
    GiftsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
