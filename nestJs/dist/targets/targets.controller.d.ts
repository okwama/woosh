import { TargetsService } from './targets.service';
import { CreateTargetDto } from './dto/create-target.dto';
export declare class TargetsController {
    private readonly targetsService;
    constructor(targetsService: TargetsService);
    create(createTargetDto: CreateTargetDto): Promise<import("./entities/target.entity").Target>;
    findAll(): Promise<import("./entities/target.entity").Target[]>;
    findOne(id: string): Promise<import("./entities/target.entity").Target>;
    update(id: string, updateTargetDto: Partial<CreateTargetDto>): Promise<import("./entities/target.entity").Target>;
    remove(id: string): Promise<void>;
}
