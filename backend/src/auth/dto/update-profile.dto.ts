import { IsOptional, IsString, MaxLength, Matches, IsUrl } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @Matches(/^[a-zA-Z0-9_]{3,20}$/)
  username?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  bio?: string;

  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['https'] })
  avatarUrl?: string;
}
