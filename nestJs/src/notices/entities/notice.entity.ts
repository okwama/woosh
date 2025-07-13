import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('NoticeBoard')
export class Notice {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 191 })
  title: string;

  @Column({ length: 191 })
  content: string;

  @Column({ name: 'countryId', type: 'int', nullable: true })
  countryId: number;

  @CreateDateColumn({ name: 'createdAt', type: 'datetime', precision: 3 })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt', type: 'datetime', precision: 3 })
  updatedAt: Date;
} 