import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like, In } from 'typeorm';
import { Client } from './entities/client.entity';
import { CreateClientDto } from './dto/create-client.dto';
import { SearchClientsDto } from './dto/search-clients.dto';

@Injectable()
export class ClientsService {
  constructor(
    @InjectRepository(Client)
    private clientRepository: Repository<Client>,
  ) {}

  async create(createClientDto: CreateClientDto): Promise<Client> {
    const client = this.clientRepository.create(createClientDto);
    return this.clientRepository.save(client);
  }

  async findAll(): Promise<Client[]> {
    return this.clientRepository.find({
      where: { status: 1 }, // Active clients only
      order: { name: 'ASC' },
    });
  }

  async findOne(id: number): Promise<Client | null> {
    return this.clientRepository.findOne({
      where: { id, status: 1 },
    });
  }

  async update(id: number, updateClientDto: Partial<CreateClientDto>): Promise<Client | null> {
    await this.clientRepository.update(id, updateClientDto);
    return this.findOne(id);
  }

  async remove(id: number): Promise<void> {
    await this.clientRepository.update(id, { status: 0 }); // Soft delete
  }

  async search(searchDto: SearchClientsDto): Promise<Client[]> {
    const { query, countryId, regionId, routeId, status } = searchDto;
    
    const whereConditions: any = {};
    
    if (countryId) whereConditions.countryId = countryId;
    if (regionId) whereConditions.regionId = regionId;
    if (routeId) whereConditions.routeId = routeId;
    if (status !== undefined) whereConditions.status = status;
    
    const queryBuilder = this.clientRepository.createQueryBuilder('client');
    
    // Add where conditions
    Object.keys(whereConditions).forEach(key => {
      queryBuilder.andWhere(`client.${key} = :${key}`, { [key]: whereConditions[key] });
    });
    
    // Add search query
    if (query) {
      queryBuilder.andWhere(
        '(client.name LIKE :query OR client.contact LIKE :query OR client.email LIKE :query OR client.address LIKE :query)',
        { query: `%${query}%` }
      );
    }
    
    return queryBuilder
      .orderBy('client.name', 'ASC')
      .getMany();
  }

  async findByCountry(countryId: number): Promise<Client[]> {
    return this.clientRepository.find({
      where: { countryId, status: 1 },
      order: { name: 'ASC' },
    });
  }

  async findByRegion(regionId: number): Promise<Client[]> {
    return this.clientRepository.find({
      where: { regionId, status: 1 },
      order: { name: 'ASC' },
    });
  }

  async findByRoute(routeId: number): Promise<Client[]> {
    return this.clientRepository.find({
      where: { routeId, status: 1 },
      order: { name: 'ASC' },
    });
  }

  async findByLocation(latitude: number, longitude: number, radius: number = 10): Promise<Client[]> {
    // Simple distance calculation using Haversine formula
    const query = `
      SELECT *, 
        (6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) AS distance
      FROM Clients 
      WHERE status = 1 
      HAVING distance <= ?
      ORDER BY distance
    `;
    
    return this.clientRepository.query(query, [latitude, longitude, latitude, radius]);
  }

  async getClientStats(countryId?: number, regionId?: number): Promise<any> {
    const queryBuilder = this.clientRepository.createQueryBuilder('client');
    
    if (countryId) {
      queryBuilder.where('client.countryId = :countryId', { countryId });
    }
    if (regionId) {
      queryBuilder.andWhere('client.regionId = :regionId', { regionId });
    }
    
    const total = await queryBuilder.getCount();
    const active = await queryBuilder.where('client.status = 1').getCount();
    const inactive = await queryBuilder.where('client.status = 0').getCount();
    
    return {
      total,
      active,
      inactive,
      activePercentage: total > 0 ? Math.round((active / total) * 100) : 0,
    };
  }
} 