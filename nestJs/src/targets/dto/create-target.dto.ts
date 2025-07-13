import { IsNumber, IsOptional, IsBoolean } from 'class-validator';

export class CreateTargetDto {
  @IsNumber()
  salesRepId: number;

  @IsOptional()
  @IsBoolean()
  isCurrent?: boolean;

  @IsNumber()
  targetValue: number;

  @IsOptional()
  @IsNumber()
  achievedValue?: number;

  @IsOptional()
  @IsBoolean()
  achieved?: boolean;
} 