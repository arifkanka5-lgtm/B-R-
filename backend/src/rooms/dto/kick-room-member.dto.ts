import { IsUUID } from 'class-validator';

export class KickRoomMemberDto {
  @IsUUID()
  userPublicId!: string;
}
