import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JourneyPlansController } from './journey-plans.controller';
import { JourneyPlansService } from './journey-plans.service';
import { JourneyPlan } from './entities/journey-plan.entity';

@Module({
  imports: [TypeOrmModule.forFeature([JourneyPlan])],
  controllers: [JourneyPlansController],
  providers: [JourneyPlansService],
  exports: [JourneyPlansService],
})
export class JourneyPlansModule {} 