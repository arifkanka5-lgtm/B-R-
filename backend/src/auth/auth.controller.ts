import { UpdateProfileDto } from './dto/update-profile.dto.js';
import { JwtAuthGuard } from './jwt-auth.guard.js';
import { Body, Controller, Post, Get, UseGuards, Req, Patch } from '@nestjs/common';
import { AuthService } from './auth.service.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }


  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() request: { user: { sub: string } }) {
    return this.authService.getProfile(request.user.sub);
  }


  @UseGuards(JwtAuthGuard)
  @Patch('me')
  updateMe(
    @Req() request: { user: { sub: string } },
    @Body() dto: UpdateProfileDto,
  ) {
    return this.authService.updateProfile(request.user.sub, dto);
  }

}
