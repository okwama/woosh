import { ClientsService } from './clients.service';
import { CreateClientDto } from './dto/create-client.dto';
import { SearchClientsDto } from './dto/search-clients.dto';
export declare class ClientsController {
    private readonly clientsService;
    constructor(clientsService: ClientsService);
    create(createClientDto: CreateClientDto): Promise<import("./entities/client.entity").Client>;
    findAll(searchDto: SearchClientsDto): Promise<import("./entities/client.entity").Client[]>;
    search(searchDto: SearchClientsDto): Promise<import("./entities/client.entity").Client[]>;
    getStats(countryId?: number, regionId?: number): Promise<any>;
    findByCountry(countryId: string): Promise<import("./entities/client.entity").Client[]>;
    findByRegion(regionId: string): Promise<import("./entities/client.entity").Client[]>;
    findByRoute(routeId: string): Promise<import("./entities/client.entity").Client[]>;
    findByLocation(latitude: string, longitude: string, radius?: string): Promise<import("./entities/client.entity").Client[]>;
    findOne(id: string): Promise<import("./entities/client.entity").Client>;
    update(id: string, updateClientDto: Partial<CreateClientDto>): Promise<import("./entities/client.entity").Client>;
    remove(id: string): Promise<void>;
}
