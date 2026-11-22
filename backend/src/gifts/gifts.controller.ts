import {
  Controller,
  Get,
  Param,
  Query,
} from '@nestjs/common';
import { GiftsService } from './gifts.service.js';

@Controller('gifts')
export class GiftsController {
  constructor(
    private readonly giftsService: GiftsService,
  ) {}

  @Get()
  findAll(@Query('category') category?: string) {
    return this.giftsService.findAll(category);
  }

  @Get(':code')
  findOne(@Param('code') code: string) {
    return this.giftsService.findOne(code);
  }
}
