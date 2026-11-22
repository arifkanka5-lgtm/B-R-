import { IsUUID } from 'class-validator';

export class TransferRoomOwnerDto {
  @IsUUID()
  newOwnerPublicId!: string;
}
