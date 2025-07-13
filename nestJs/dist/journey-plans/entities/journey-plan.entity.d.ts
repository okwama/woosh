import { User } from '../../users/entities/user.entity';
import { Client } from '../../clients/entities/client.entity';
export declare class JourneyPlan {
    id: number;
    date: Date;
    time: string;
    userId: number;
    user: User;
    clientId: number;
    client: Client;
    status: number;
    checkInTime: Date;
    latitude: number;
    longitude: number;
    imageUrl: string;
    notes: string;
    checkoutLatitude: number;
    checkoutLongitude: number;
    checkoutTime: Date;
    showUpdateLocation: boolean;
    routeId: number;
}
