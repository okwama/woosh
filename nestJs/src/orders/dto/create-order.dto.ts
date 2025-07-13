import { IsString, IsNumber, IsOptional, IsDecimal, IsDateString } from 'class-validator';

export class CreateOrderDto {
  @IsNumber()
  totalAmount: number;

  @IsDecimal()
  totalCost: number;

  @IsDecimal()
  amountPaid: number;

  @IsDecimal()
  balance: number;

  @IsString()
  comment: string;

  @IsString()
  customerType: string;

  @IsString()
  customerId: string;

  @IsString()
  customerName: string;

  @IsDateString()
  orderDate: string;

  @IsOptional()
  @IsNumber()
  riderId?: number;

  @IsOptional()
  @IsString()
  riderName?: string;

  @IsOptional()
  @IsNumber()
  status?: number;

  @IsOptional()
  @IsString()
  approvedTime?: string;

  @IsOptional()
  @IsString()
  dispatchTime?: string;

  @IsOptional()
  @IsString()
  deliveryLocation?: string;

  @IsOptional()
  @IsString()
  completeLatitude?: string;

  @IsOptional()
  @IsString()
  completeLongitude?: string;

  @IsOptional()
  @IsString()
  completeAddress?: string;

  @IsOptional()
  @IsString()
  pickupTime?: string;

  @IsOptional()
  @IsString()
  deliveryTime?: string;

  @IsOptional()
  @IsString()
  cancelReason?: string;

  @IsOptional()
  @IsString()
  recepient?: string;

  @IsNumber()
  userId: number;

  @IsNumber()
  clientId: number;

  @IsNumber()
  countryId: number;

  @IsNumber()
  regionId: number;

  @IsString()
  approvedBy: string;

  @IsString()
  approvedByName: string;

  @IsOptional()
  @IsNumber()
  storeId?: number;

  @IsNumber()
  retailManager: number;

  @IsNumber()
  keyChannelManager: number;

  @IsNumber()
  distributionManager: number;

  @IsOptional()
  @IsString()
  imageUrl?: string;
} 