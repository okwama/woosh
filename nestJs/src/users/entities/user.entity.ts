import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  BeforeInsert,
  BeforeUpdate,
} from 'typeorm';
import { Exclude } from 'class-transformer';
import * as bcrypt from 'bcryptjs';

export enum UserRole {
  ADMIN = 'admin',
  USER = 'USER',
  MANAGER = 'manager',
  RIDER = 'rider',
}

@Entity('SalesRep')
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 191 })
  name: string;

  @Column({ unique: true, length: 191 })
  email: string;

  @Column({ name: 'phoneNumber', length: 191 })
  phone: string;

  @Column({ length: 191 })
  @Exclude()
  password: string;

  @Column({ name: 'countryId', type: 'int' })
  countryId: number;

  @Column({ length: 191 })
  country: string;

  @Column({ name: 'region_id', type: 'int' })
  regionId: number;

  @Column({ length: 191 })
  region: string;

  @Column({ name: 'route_id', type: 'int' })
  routeId: number;

  @Column({ length: 100 })
  route: string;

  @Column({ name: 'route_id_update', type: 'int' })
  routeIdUpdate: number;

  @Column({ name: 'route_name_update', length: 100 })
  routeNameUpdate: string;

  @Column({ name: 'visits_targets', type: 'int', default: 0 })
  visitsTargets: number;

  @Column({ name: 'new_clients', type: 'int', default: 0 })
  newClients: number;

  @Column({ name: 'vapes_targets', type: 'int', default: 0 })
  vapesTargets: number;

  @Column({ name: 'pouches_targets', type: 'int', default: 0 })
  pouchesTargets: number;

  @Column({ length: 191, default: 'USER' })
  role: string;

  @Column({ name: 'manager_type', type: 'int' })
  managerType: number;

  @Column({ type: 'int', default: 0 })
  status: number;

  @Column({ name: 'retail_manager', type: 'int' })
  retailManager: number;

  @Column({ name: 'key_channel_manager', type: 'int' })
  keyChannelManager: number;

  @Column({ name: 'distribution_manager', type: 'int' })
  distributionManager: number;

  @Column({ name: 'photoUrl', length: 191, default: '' })
  photoUrl: string;

  @Column({ name: 'managerId', type: 'int', nullable: true })
  managerId: number;

  @CreateDateColumn({ name: 'createdAt', type: 'datetime', precision: 3 })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt', type: 'datetime', precision: 3 })
  updatedAt: Date;

  @BeforeInsert()
  @BeforeUpdate()
  async hashPassword() {
    if (this.password) {
      this.password = await bcrypt.hash(this.password, 12);
    }
  }

  async validatePassword(password: string): Promise<boolean> {
    return bcrypt.compare(password, this.password);
  }

  get fullName(): string {
    return this.name || '';
  }
} 