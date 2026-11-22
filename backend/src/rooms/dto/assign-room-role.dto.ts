import { IsIn, IsUUID } from 'class-validator';

export class AssignRoomRoleDto {
  @IsUUID()
  userPublicId!: string;

  @IsIn(['ADMIN', 'MODERATOR', 'MEMBER'])
  role!: 'ADMIN' | 'MODERATOR' | 'MEMBER';
}
