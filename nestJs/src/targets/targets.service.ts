import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Target } from './entities/target.entity';
import { CreateTargetDto } from './dto/create-target.dto';

@Injectable()
export class TargetsService {
  constructor(
    @InjectRepository(Target)
    private targetRepository: Repository<Target>,
  ) {}

  async create(createTargetDto: CreateTargetDto): Promise<Target> {
    const target = this.targetRepository.create(createTargetDto);
    return this.targetRepository.save(target);
  }

  async findAll(): Promise<Target[]> {
    return this.targetRepository.find({
      relations: ['salesRep'],
    });
  }

  async findOne(id: number): Promise<Target | null> {
    return this.targetRepository.findOne({
      where: { id },
      relations: ['salesRep'],
    });
  }

  async update(id: number, updateTargetDto: Partial<CreateTargetDto>): Promise<Target | null> {
    await this.targetRepository.update(id, updateTargetDto);
    return this.findOne(id);
  }

  async remove(id: number): Promise<void> {
    await this.targetRepository.delete(id);
  }
} 