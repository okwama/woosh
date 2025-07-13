import { User } from '../../users/entities/user.entity';
export declare class Client {
    id: number;
    name: string;
    address: string;
    latitude: number;
    longitude: number;
    balance: number;
    email: string;
    regionId: number;
    region: string;
    routeId: number;
    routeName: string;
    routeIdUpdate: number;
    routeNameUpdate: string;
    contact: string;
    taxPin: string;
    location: string;
    status: number;
    clientType: number;
    outletAccount: number;
    countryId: number;
    addedBy: number;
    addedByUser: User;
    createdAt: Date;
    updatedAt: Date;
}
