import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Client } from '../../clients/entities/client.entity';

@Entity('JourneyPlan')
export class JourneyPlan {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'datetime', precision: 3 })
  date: Date;

  @Column({ length: 191 })
  time: string;

  @Column({ name: 'userId', type: 'int', nullable: true })
  userId: number;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ name: 'clientId', type: 'int' })
  clientId: number;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'clientId' })
  client: Client;

  @Column({ type: 'int', default: 0 })
  status: number;

  @Column({ name: 'checkInTime', type: 'datetime', precision: 3, nullable: true })
  checkInTime: Date;

  @Column({ type: 'double', nullable: true })
  latitude: number;

  @Column({ type: 'double', nullable: true })
  longitude: number;

  @Column({ name: 'imageUrl', length: 191, nullable: true })
  imageUrl: string;

  @Column({ length: 191, nullable: true })
  notes: string;

  @Column({ type: 'double', nullable: true })
  checkoutLatitude: number;

  @Column({ type: 'double', nullable: true })
  checkoutLongitude: number;

  @Column({ name: 'checkoutTime', type: 'datetime', precision: 3, nullable: true })
  checkoutTime: Date;

  @Column({ name: 'showUpdateLocation', type: 'tinyint', default: 1 })
  showUpdateLocation: boolean;

  @Column({ name: 'routeId', type: 'int', nullable: true })
  routeId: number;
} 