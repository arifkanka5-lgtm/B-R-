import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { ManualPaymentService } from './manual-payment.service.js';

class CreatePaymentRequestDto {
  @IsString()
  packageId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  paymentReference?: string;
}

@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class ManualPaymentController {
  constructor(
    private readonly payments: ManualPaymentService,
  ) {}

  @Get('packages')
  packages() {
    return this.payments.getPackages();
  }

  @Post('topups')
  create(
    @Req() request: { user: { sub: string } },
    @Body() dto: CreatePaymentRequestDto,
  ) {
    return this.payments.createRequest(
      request.user.sub,
      dto.packageId,
      dto.paymentReference,
    );
  }

  @Get('topups')
  myTopups(@Req() request: { user: { sub: string } }) {
    return this.payments.myRequests(request.user.sub);
  }
}
