import { Client } from '../../clients/entities/client.entity';
export declare class Product {
    id: number;
    name: string;
    categoryId: number;
    category: string;
    unitCost: number;
    description: string;
    currentStock: number;
    unitCostNgn: number;
    unitCostTzs: number;
    clientId: number;
    client: Client;
    image: string;
    createdAt: Date;
    updatedAt: Date;
}
