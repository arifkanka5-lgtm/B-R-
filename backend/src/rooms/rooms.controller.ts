import { Body, Controller, Post, Req, UseGuards, Get, Param, Delete, Patch } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { CreateRoomDto } from './dto/create-room.dto.js';
import { JoinRoomDto } from './dto/join-room.dto.js';
import { RoomsService } from './rooms.service.js';
import { RoomsGateway } from './rooms.gateway.js';
import { TransferRoomOwnerDto } from './dto/transfer-room-owner.dto.js';
import { AssignRoomRoleDto } from './dto/assign-room-role.dto.js';

import { KickRoomMemberDto } from './dto/kick-room-member.dto.js';

@Controller('rooms')
export class RoomsController {
  constructor(
    private readonly roomsService: RoomsService,
    private readonly roomsGateway: RoomsGateway,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @Req() request: { user: { sub: string } },
    @Body() dto: CreateRoomDto,
  ) {
    return this.roomsService.createRoom(request.user.sub, dto);
  }

  @Get()
  list() {
    return this.roomsService.listRooms();
  }

  @UseGuards(JwtAuthGuard)
  @Post(':publicId/join')
  join(
    @Param('publicId') roomPublicId: string,
    @Req() request: { user: { sub: string } },
    @Body() dto: JoinRoomDto,
  ) {
    return this.roomsService.joinRoom(
      request.user.sub,
      roomPublicId,
      dto,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':publicId/leave')
  leave(
    @Param('publicId') roomPublicId: string,
    @Req() request: { user: { sub: string } },
  ) {
    return this.roomsService.leaveRoom(
      request.user.sub,
      roomPublicId,
    );
  }


  @UseGuards(JwtAuthGuard)
  @Post(':publicId/transfer-owner')
  transferOwner(
    @Param('publicId') roomPublicId: string,
    @Req() request: { user: { sub: string } },
    @Body() dto: TransferRoomOwnerDto,
  ) {
    return this.roomsService.transferRoomOwner(
      request.user.sub,
      roomPublicId,
      dto,
    );
  }


  @UseGuards(JwtAuthGuard)
  @Post(':publicId/assign-role')
  assignRole(
    @Param('publicId') roomPublicId: string,
    @Req() request: { user: { sub: string } },
    @Body() dto: AssignRoomRoleDto,
  ) {
    return this.roomsService.assignRoomRole(
      request.user.sub,
      roomPublicId,
      dto,
    );
  }


  @UseGuards(JwtAuthGuard)
  @Post(':publicId/kick')
  kickMember(
    @Param('publicId') roomPublicId: string,
    @Req() request: { user: { sub: string } },
    @Body() dto: KickRoomMemberDto,
  ) {
    return this.roomsService.kickRoomMember(
      request.user.sub,
      roomPublicId,
      dto,
    );
  }


  @UseGuards(JwtAuthGuard)
  @Get(':publicId/seats')
  seats(@Param('publicId') id: string) {
    return this.roomsService.listRoomSeats(id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':publicId/seats/:seatNumber/sit')
  async sit(
    @Param('publicId') id: string,
    @Param('seatNumber') number: string,
    @Req() request: { user: { sub: string } },
  ) {
    const result = await this.roomsService.sitOnSeat(
      request.user.sub, id, Number(number),
    );
    await this.roomsGateway.broadcastRoomSeats(id);
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':publicId/seats/leave')
  async leaveSeat(
    @Param('publicId') id: string,
    @Req() request: { user: { sub: string } },
  ) {
    const result = await this.roomsService.leaveSeat(request.user.sub, id);
    await this.roomsGateway.broadcastRoomSeats(id);
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':publicId/seats/:seatNumber/lock')
  async lockSeat(
    @Param('publicId') id: string,
    @Param('seatNumber') number: string,
    @Body() body: { isLocked: boolean },
    @Req() request: { user: { sub: string } },
  ) {
    const result = await this.roomsService.setSeatLock(
      request.user.sub, id, Number(number), body.isLocked,
    );
    await this.roomsGateway.broadcastRoomSeats(id);
    return result;
  }

  @Get(':publicId/members')
  members(@Param('publicId') roomPublicId: string) {
    return this.roomsService.listRoomMembers(roomPublicId);
  }
}
