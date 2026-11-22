import {
  Controller,
  Get,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { WalletService } from './wallet.service.js';

@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get()
  getWallet(@Req() request: { user: { sub: string } }) {
    return this.walletService.getWallet(request.user.sub);
  }

  @Get('transactions')
  getTransactions(
    @Req() request: { user: { sub: string } },
    @Query('page') page?: string,
  ) {
    const pageNumber = Number(page ?? 1);

    return this.walletService.getTransactions(
      request.user.sub,
      Number.isInteger(pageNumber) && pageNumber > 0
        ? Math.min(pageNumber, 100000)
        : 1,
    );
  }
}
