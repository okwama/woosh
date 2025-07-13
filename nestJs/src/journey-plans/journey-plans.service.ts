import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JourneyPlan } from './entities/journey-plan.entity';
import { CreateJourneyPlanDto } from './dto/create-journey-plan.dto';

@Injectable()
export class JourneyPlansService {
  constructor(
    @InjectRepository(JourneyPlan)
    private journeyPlanRepository: Repository<JourneyPlan>,
  ) {}

  async create(createJourneyPlanDto: CreateJourneyPlanDto): Promise<JourneyPlan> {
    const journeyPlan = this.journeyPlanRepository.create(createJourneyPlanDto);
    return this.journeyPlanRepository.save(journeyPlan);
  }

  async findAll(): Promise<JourneyPlan[]> {
    return this.journeyPlanRepository.find({
      relations: ['user', 'client'],
    });
  }

  async findOne(id: number): Promise<JourneyPlan | null> {
    return this.journeyPlanRepository.findOne({
      where: { id },
      relations: ['user', 'client'],
    });
  }

  async update(id: number, updateJourneyPlanDto: Partial<CreateJourneyPlanDto>): Promise<JourneyPlan | null> {
    await this.journeyPlanRepository.update(id, updateJourneyPlanDto);
    return this.findOne(id);
  }

  async remove(id: number): Promise<void> {
    await this.journeyPlanRepository.delete(id);
  }
} 