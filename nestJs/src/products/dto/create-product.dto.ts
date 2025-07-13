import { IsString, IsNumber, IsOptional, IsDecimal } from 'class-validator';

export class CreateProductDto {
  @IsString()
  name: string;

  @IsNumber()
  categoryId: number;

  @IsString()
  category: string;

  @IsDecimal()
  unitCost: number;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsNumber()
  currentStock?: number;

  @IsOptional()
  @IsDecimal()
  unitCostNgn?: number;

  @IsOptional()
  @IsDecimal()
  unitCostTzs?: number;

  @IsOptional()
  @IsNumber()
  clientId?: number;

  @IsOptional()
  @IsString()
  image?: string;
} 