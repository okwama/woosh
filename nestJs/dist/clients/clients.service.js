"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClientsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const client_entity_1 = require("./entities/client.entity");
let ClientsService = class ClientsService {
    constructor(clientRepository) {
        this.clientRepository = clientRepository;
    }
    async create(createClientDto) {
        const client = this.clientRepository.create(createClientDto);
        return this.clientRepository.save(client);
    }
    async findAll() {
        return this.clientRepository.find({
            where: { status: 1 },
            order: { name: 'ASC' },
        });
    }
    async findOne(id) {
        return this.clientRepository.findOne({
            where: { id, status: 1 },
        });
    }
    async update(id, updateClientDto) {
        await this.clientRepository.update(id, updateClientDto);
        return this.findOne(id);
    }
    async remove(id) {
        await this.clientRepository.update(id, { status: 0 });
    }
    async search(searchDto) {
        const { query, countryId, regionId, routeId, status } = searchDto;
        const whereConditions = {};
        if (countryId)
            whereConditions.countryId = countryId;
        if (regionId)
            whereConditions.regionId = regionId;
        if (routeId)
            whereConditions.routeId = routeId;
        if (status !== undefined)
            whereConditions.status = status;
        const queryBuilder = this.clientRepository.createQueryBuilder('client');
        Object.keys(whereConditions).forEach(key => {
            queryBuilder.andWhere(`client.${key} = :${key}`, { [key]: whereConditions[key] });
        });
        if (query) {
            queryBuilder.andWhere('(client.name LIKE :query OR client.contact LIKE :query OR client.email LIKE :query OR client.address LIKE :query)', { query: `%${query}%` });
        }
        return queryBuilder
            .orderBy('client.name', 'ASC')
            .getMany();
    }
    async findByCountry(countryId) {
        return this.clientRepository.find({
            where: { countryId, status: 1 },
            order: { name: 'ASC' },
        });
    }
    async findByRegion(regionId) {
        return this.clientRepository.find({
            where: { regionId, status: 1 },
            order: { name: 'ASC' },
        });
    }
    async findByRoute(routeId) {
        return this.clientRepository.find({
            where: { routeId, status: 1 },
            order: { name: 'ASC' },
        });
    }
    async findByLocation(latitude, longitude, radius = 10) {
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
    async getClientStats(countryId, regionId) {
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
};
exports.ClientsService = ClientsService;
exports.ClientsService = ClientsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(client_entity_1.Client)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], ClientsService);
//# sourceMappingURL=clients.service.js.map