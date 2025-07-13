import { IsString, IsEmail, IsNumber, IsOptional, IsIn } from 'class-validator';

export class CreateUserDto {
  @IsString()
  name: string;

  @IsEmail()
  email: string;

  @IsString()
  phoneNumber: string;

  @IsString()
  password: string;

  @IsNumber()
  countryId: number;

  @IsString()
  country: string;

  @IsNumber()
  regionId: number;

  @IsString()
  region: string;

  @IsNumber()
  routeId: number;

  @IsString()
  route: string;

  @IsNumber()
  routeIdUpdate: number;

  @IsString()
  routeNameUpdate: string;

  @IsOptional()
  @IsNumber()
  visitsTargets?: number;

  @IsOptional()
  @IsNumber()
  newClients?: number;

  @IsOptional()
  @IsNumber()
  vapesTargets?: number;

  @IsOptional()
  @IsNumber()
  pouchesTargets?: number;

  @IsOptional()
  @IsString()
  role?: string;

  @IsNumber()
  managerType: number;

  @IsOptional()
  @IsNumber()
  status?: number;

  @IsNumber()
  retailManager: number;

  @IsNumber()
  keyChannelManager: number;

  @IsNumber()
  distributionManager: number;

  @IsOptional()
  @IsString()
  photoUrl?: string;

  @IsOptional()
  @IsNumber()
  managerId?: number;
} 