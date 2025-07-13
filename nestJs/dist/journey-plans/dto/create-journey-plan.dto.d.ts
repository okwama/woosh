export declare class CreateJourneyPlanDto {
    date: string;
    time: string;
    userId?: number;
    clientId: number;
    status?: number;
    checkInTime?: string;
    latitude?: number;
    longitude?: number;
    imageUrl?: string;
    notes?: string;
    checkoutLatitude?: number;
    checkoutLongitude?: number;
    checkoutTime?: string;
    showUpdateLocation?: boolean;
    routeId?: number;
}
