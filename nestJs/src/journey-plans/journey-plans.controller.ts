import { Controller, Get, Post, Body, Patch, Param, Delete, UseGuards } from '@nestjs/common';
import { JourneyPlansService } from './journey-plans.service';
import { CreateJourneyPlanDto } from './dto/create-journey-plan.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('journey-plans')
@UseGuards(JwtAuthGuard)
export class JourneyPlansController {
  constructor(private readonly journeyPlansService: JourneyPlansService) {}

  @Post()
  create(@Body() createJourneyPlanDto: CreateJourneyPlanDto) {
    return this.journeyPlansService.create(createJourneyPlanDto);
  }

  @Get()
  findAll() {
    return this.journeyPlansService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.journeyPlansService.findOne(+id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateJourneyPlanDto: Partial<CreateJourneyPlanDto>) {
    return this.journeyPlansService.update(+id, updateJourneyPlanDto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.journeyPlansService.remove(+id);
  }
} 