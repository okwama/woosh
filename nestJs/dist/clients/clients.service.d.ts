import { Repository } from 'typeorm';
import { Client } from './entities/client.entity';
import { CreateClientDto } from './dto/create-client.dto';
import { SearchClientsDto } from './dto/search-clients.dto';
export declare class ClientsService {
    private clientRepository;
    constructor(clientRepository: Repository<Client>);
    create(createClientDto: CreateClientDto): Promise<Client>;
    findAll(): Promise<Client[]>;
    findOne(id: number): Promise<Client | null>;
    update(id: number, updateClientDto: Partial<CreateClientDto>): Promise<Client | null>;
    remove(id: number): Promise<void>;
    search(searchDto: SearchClientsDto): Promise<Client[]>;
    findByCountry(countryId: number): Promise<Client[]>;
    findByRegion(regionId: number): Promise<Client[]>;
    findByRoute(routeId: number): Promise<Client[]>;
    findByLocation(latitude: number, longitude: number, radius?: number): Promise<Client[]>;
    getClientStats(countryId?: number, regionId?: number): Promise<any>;
}
