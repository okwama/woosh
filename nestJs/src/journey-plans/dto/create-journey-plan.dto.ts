import { IsString, IsNumber, IsOptional, IsBoolean, IsDateString } from 'class-validator';

export class CreateJourneyPlanDto {
  @IsDateString()
  date: string;

  @IsString()
  time: string;

  @IsOptional()
  @IsNumber()
  userId?: number;

  @IsNumber()
  clientId: number;

  @IsOptional()
  @IsNumber()
  status?: number;

  @IsOptional()
  @IsDateString()
  checkInTime?: string;

  @IsOptional()
  @IsNumber()
  latitude?: number;

  @IsOptional()
  @IsNumber()
  longitude?: number;

  @IsOptional()
  @IsString()
  imageUrl?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsNumber()
  checkoutLatitude?: number;

  @IsOptional()
  @IsNumber()
  checkoutLongitude?: number;

  @IsOptional()
  @IsDateString()
  checkoutTime?: string;

  @IsOptional()
  @IsBoolean()
  showUpdateLocation?: boolean;

  @IsOptional()
  @IsNumber()
  routeId?: number;
} 