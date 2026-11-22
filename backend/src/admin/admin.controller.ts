import { Controller, Get, Patch, Param, Query, Req, UseGuards, ParseBoolPipe, Body } from '@nestjs/common';
import { IsBoolean } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { AdminGuard } from './admin.guard.js';
import { AdminService } from './admin.service.js';

class SetActiveDto { @IsBoolean() active!:boolean; }
@Controller('admin')
@UseGuards(JwtAuthGuard, AdminGuard)
export class AdminController {
  constructor(private readonly admin:AdminService) {}
  @Get('stats') stats(){return this.admin.stats();}
  @Get('users') users(@Query('limit') limit?:string,@Query('offset') offset?:string){return this.admin.users(limit,offset);}
  @Get('rooms') rooms(@Query('limit') limit?:string,@Query('offset') offset?:string){return this.admin.rooms(limit,offset);}
  @Get('audit') audit(@Query('limit') limit?:string,@Query('offset') offset?:string){return this.admin.audit(limit,offset);}
  @Patch('users/:publicId/active') userActive(@Req() req:{user:{sub:string}},@Param('publicId') id:string,@Body() body:SetActiveDto){return this.admin.setUserActive(req.user.sub,id,body.active);}
  @Patch('rooms/:publicId/active') roomActive(@Req() req:{user:{sub:string}},@Param('publicId') id:string,@Body() body:SetActiveDto){return this.admin.setRoomActive(req.user.sub,id,body.active);}
}
