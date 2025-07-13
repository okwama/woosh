import { IsString, IsOptional, IsNumber, IsEmail, IsDecimal } from 'class-validator';

export class CreateClientDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsNumber()
  latitude?: number;

  @IsOptional()
  @IsNumber()
  longitude?: number;

  @IsOptional()
  @IsDecimal()
  balance?: number;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsNumber()
  regionId: number;

  @IsString()
  region: string;

  @IsOptional()
  @IsNumber()
  routeId?: number;

  @IsOptional()
  @IsString()
  routeName?: string;

  @IsOptional()
  @IsNumber()
  routeIdUpdate?: number;

  @IsOptional()
  @IsString()
  routeNameUpdate?: string;

  @IsString()
  contact: string;

  @IsOptional()
  @IsString()
  taxPin?: string;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsNumber()
  clientType?: number;

  @IsOptional()
  @IsNumber()
  outletAccount?: number;

  @IsNumber()
  countryId: number;

  @IsOptional()
  @IsNumber()
  addedBy?: number;
} 