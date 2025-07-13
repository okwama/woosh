export declare class CreateUserDto {
    name: string;
    email: string;
    phoneNumber: string;
    password: string;
    countryId: number;
    country: string;
    regionId: number;
    region: string;
    routeId: number;
    route: string;
    routeIdUpdate: number;
    routeNameUpdate: string;
    visitsTargets?: number;
    newClients?: number;
    vapesTargets?: number;
    pouchesTargets?: number;
    role?: string;
    managerType: number;
    status?: number;
    retailManager: number;
    keyChannelManager: number;
    distributionManager: number;
    photoUrl?: string;
    managerId?: number;
}
