import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Client } from '../../clients/entities/client.entity';
import { OrderItem } from './order-item.entity';

@Entity('MyOrder')
export class Order {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'totalAmount', type: 'double' })
  totalAmount: number;

  @Column({ name: 'totalCost', type: 'decimal', precision: 11, scale: 2 })
  totalCost: number;

  @Column({ name: 'amountPaid', type: 'decimal', precision: 11, scale: 2 })
  amountPaid: number;

  @Column({ type: 'decimal', precision: 11, scale: 2 })
  balance: number;

  @Column({ length: 191 })
  comment: string;

  @Column({ name: 'customerType', length: 191 })
  customerType: string;

  @Column({ name: 'customerId', length: 191 })
  customerId: string;

  @Column({ name: 'customerName', length: 191 })
  customerName: string;

  @Column({ name: 'orderDate', type: 'datetime', precision: 3 })
  orderDate: Date;

  @Column({ name: 'riderId', type: 'int', nullable: true })
  riderId: number;

  @Column({ name: 'riderName', length: 191, nullable: true })
  riderName: string;

  @Column({ type: 'int', default: 0 })
  status: number;

  @Column({ name: 'approvedTime', length: 191, nullable: true })
  approvedTime: string;

  @Column({ name: 'dispatchTime', length: 191, nullable: true })
  dispatchTime: string;

  @Column({ name: 'deliveryLocation', length: 191, nullable: true })
  deliveryLocation: string;

  @Column({ name: 'complete_latitude', length: 191, nullable: true })
  completeLatitude: string;

  @Column({ name: 'complete_longitude', length: 191, nullable: true })
  completeLongitude: string;

  @Column({ name: 'complete_address', length: 191, nullable: true })
  completeAddress: string;

  @Column({ name: 'pickupTime', length: 191, nullable: true })
  pickupTime: string;

  @Column({ name: 'deliveryTime', length: 191, nullable: true })
  deliveryTime: string;

  @Column({ name: 'cancel_reason', length: 191, nullable: true })
  cancelReason: string;

  @Column({ length: 191, nullable: true })
  recepient: string;

  @Column({ name: 'userId', type: 'int' })
  userId: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ name: 'clientId', type: 'int' })
  clientId: number;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'clientId' })
  client: Client;

  @Column({ name: 'countryId', type: 'int' })
  countryId: number;

  @Column({ name: 'regionId', type: 'int' })
  regionId: number;

  @Column({ name: 'approved_by', length: 200 })
  approvedBy: string;

  @Column({ name: 'approved_by_name', length: 200 })
  approvedByName: string;

  @Column({ name: 'storeId', type: 'int', nullable: true })
  storeId: number;

  @Column({ name: 'retail_manager', type: 'int' })
  retailManager: number;

  @Column({ name: 'key_channel_manager', type: 'int' })
  keyChannelManager: number;

  @Column({ name: 'distribution_manager', type: 'int' })
  distributionManager: number;

  @Column({ name: 'imageUrl', length: 191, nullable: true })
  imageUrl: string;

  @OneToMany(() => OrderItem, orderItem => orderItem.order)
  orderItems: OrderItem[];

  @CreateDateColumn({ name: 'createdAt', type: 'datetime', precision: 3 })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt', type: 'datetime', precision: 3 })
  updatedAt: Date;
} 