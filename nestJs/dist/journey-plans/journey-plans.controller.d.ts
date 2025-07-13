import { JourneyPlansService } from './journey-plans.service';
import { CreateJourneyPlanDto } from './dto/create-journey-plan.dto';
export declare class JourneyPlansController {
    private readonly journeyPlansService;
    constructor(journeyPlansService: JourneyPlansService);
    create(createJourneyPlanDto: CreateJourneyPlanDto): Promise<import("./entities/journey-plan.entity").JourneyPlan>;
    findAll(): Promise<import("./entities/journey-plan.entity").JourneyPlan[]>;
    findOne(id: string): Promise<import("./entities/journey-plan.entity").JourneyPlan>;
    update(id: string, updateJourneyPlanDto: Partial<CreateJourneyPlanDto>): Promise<import("./entities/journey-plan.entity").JourneyPlan>;
    remove(id: string): Promise<void>;
}
