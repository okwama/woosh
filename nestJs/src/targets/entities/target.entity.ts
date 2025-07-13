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

@Entity('Target')
export class Target {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'salesRepId', type: 'int' })
  salesRepId: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'salesRepId' })
  salesRep: User;

  @Column({ name: 'isCurrent', type: 'tinyint', default: 0 })
  isCurrent: boolean;

  @Column({ name: 'targetValue', type: 'int' })
  targetValue: number;

  @Column({ name: 'achievedValue', type: 'int', default: 0 })
  achievedValue: number;

  @Column({ type: 'tinyint', default: 0 })
  achieved: boolean;

  @CreateDateColumn({ name: 'createdAt', type: 'datetime', precision: 3 })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt', type: 'datetime', precision: 3 })
  updatedAt: Date;
} 