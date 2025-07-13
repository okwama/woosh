export declare enum UserRole {
    ADMIN = "admin",
    USER = "USER",
    MANAGER = "manager",
    RIDER = "rider"
}
export declare class User {
    id: number;
    name: string;
    email: string;
    phone: string;
    password: string;
    countryId: number;
    country: string;
    regionId: number;
    region: string;
    routeId: number;
    route: string;
    routeIdUpdate: number;
    routeNameUpdate: string;
    visitsTargets: number;
    newClients: number;
    vapesTargets: number;
    pouchesTargets: number;
    role: string;
    managerType: number;
    status: number;
    retailManager: number;
    keyChannelManager: number;
    distributionManager: number;
    photoUrl: string;
    managerId: number;
    createdAt: Date;
    updatedAt: Date;
    hashPassword(): Promise<void>;
    validatePassword(password: string): Promise<boolean>;
    get fullName(): string;
}
