import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Client } from '../../clients/entities/client.entity';

@Entity('Product')
export class Product {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 191 })
  name: string;

  @Column({ name: 'category_id', type: 'int' })
  categoryId: number;

  @Column({ length: 191 })
  category: string;

  @Column({ name: 'unit_cost', type: 'decimal', precision: 11, scale: 2 })
  unitCost: number;

  @Column({ length: 191, nullable: true })
  description: string;

  @Column({ name: 'currentStock', type: 'int', nullable: true })
  currentStock: number;

  @Column({ name: 'unit_cost_ngn', type: 'decimal', precision: 11, scale: 2, nullable: true })
  unitCostNgn: number;

  @Column({ name: 'unit_cost_tzs', type: 'decimal', precision: 11, scale: 2, nullable: true })
  unitCostTzs: number;

  @Column({ name: 'clientId', type: 'int', nullable: true })
  clientId: number;

  @ManyToOne(() => Client, { nullable: true })
  @JoinColumn({ name: 'clientId' })
  client: Client;

  @Column({ length: 255, nullable: true })
  image: string;

  @CreateDateColumn({ name: 'createdAt', type: 'datetime', precision: 3 })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt', type: 'datetime', precision: 3 })
  updatedAt: Date;
} 