import { Repository } from 'typeorm';
import { Target } from './entities/target.entity';
import { CreateTargetDto } from './dto/create-target.dto';
export declare class TargetsService {
    private targetRepository;
    constructor(targetRepository: Repository<Target>);
    create(createTargetDto: CreateTargetDto): Promise<Target>;
    findAll(): Promise<Target[]>;
    findOne(id: number): Promise<Target | null>;
    update(id: number, updateTargetDto: Partial<CreateTargetDto>): Promise<Target | null>;
    remove(id: number): Promise<void>;
}
