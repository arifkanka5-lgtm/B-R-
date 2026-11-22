import { Module } from '@nestjs/common';
import { ManualPaymentController } from './manual-payment.controller.js';
import { ManualPaymentService } from './manual-payment.service.js';
import { AuthModule } from '../auth/auth.module.js';
import { WalletController } from './wallet.controller.js';
import { WalletService } from './wallet.service.js';

@Module({
  imports: [AuthModule],
  controllers: [WalletController, ManualPaymentController],
  providers: [WalletService, ManualPaymentService],
  exports: [WalletService],
})
export class WalletModule {}
