import { User } from '../../users/entities/user.entity';
export declare class Target {
    id: number;
    salesRepId: number;
    salesRep: User;
    isCurrent: boolean;
    targetValue: number;
    achievedValue: number;
    achieved: boolean;
    createdAt: Date;
    updatedAt: Date;
}
