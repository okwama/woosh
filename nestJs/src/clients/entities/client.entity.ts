import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Entity('Clients')
export class Client {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 191 })
  name: string;

  @Column({ length: 191, nullable: true })
  address: string;

  @Column({ type: 'double', nullable: true })
  latitude: number;

  @Column({ type: 'double', nullable: true })
  longitude: number;

  @Column({ type: 'decimal', precision: 11, scale: 2, nullable: true })
  balance: number;

  @Column({ length: 191, nullable: true })
  email: string;

  @Column({ name: 'region_id', type: 'int' })
  regionId: number;

  @Column({ length: 191 })
  region: string;

  @Column({ name: 'route_id', type: 'int', nullable: true })
  routeId: number;

  @Column({ name: 'route_name', length: 191, nullable: true })
  routeName: string;

  @Column({ name: 'route_id_update', type: 'int', nullable: true })
  routeIdUpdate: number;

  @Column({ name: 'route_name_update', length: 100, nullable: true })
  routeNameUpdate: string;

  @Column({ length: 191 })
  contact: string;

  @Column({ name: 'tax_pin', length: 191, nullable: true })
  taxPin: string;

  @Column({ length: 191, nullable: true })
  location: string;

  @Column({ type: 'int', default: 0 })
  status: number;

  @Column({ name: 'client_type', type: 'int', nullable: true })
  clientType: number;

  @Column({ name: 'outlet_account', type: 'int', nullable: true })
  outletAccount: number;

  @Column({ name: 'countryId', type: 'int' })
  countryId: number;

  @Column({ name: 'added_by', type: 'int', nullable: true })
  addedBy: number;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'added_by' })
  addedByUser: User;

  @CreateDateColumn({ name: 'created_at', type: 'datetime', precision: 3 })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt', type: 'datetime', precision: 3 })
  updatedAt: Date;
} 