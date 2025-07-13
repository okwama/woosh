import { Repository } from 'typeorm';
import { JourneyPlan } from './entities/journey-plan.entity';
import { CreateJourneyPlanDto } from './dto/create-journey-plan.dto';
export declare class JourneyPlansService {
    private journeyPlanRepository;
    constructor(journeyPlanRepository: Repository<JourneyPlan>);
    create(createJourneyPlanDto: CreateJourneyPlanDto): Promise<JourneyPlan>;
    findAll(): Promise<JourneyPlan[]>;
    findOne(id: number): Promise<JourneyPlan | null>;
    update(id: number, updateJourneyPlanDto: Partial<CreateJourneyPlanDto>): Promise<JourneyPlan | null>;
    remove(id: number): Promise<void>;
}
