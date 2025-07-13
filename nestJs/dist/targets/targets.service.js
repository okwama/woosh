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
exports.TargetsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const target_entity_1 = require("./entities/target.entity");
let TargetsService = class TargetsService {
    constructor(targetRepository) {
        this.targetRepository = targetRepository;
    }
    async create(createTargetDto) {
        const target = this.targetRepository.create(createTargetDto);
        return this.targetRepository.save(target);
    }
    async findAll() {
        return this.targetRepository.find({
            relations: ['salesRep'],
        });
    }
    async findOne(id) {
        return this.targetRepository.findOne({
            where: { id },
            relations: ['salesRep'],
        });
    }
    async update(id, updateTargetDto) {
        await this.targetRepository.update(id, updateTargetDto);
        return this.findOne(id);
    }
    async remove(id) {
        await this.targetRepository.delete(id);
    }
};
exports.TargetsService = TargetsService;
exports.TargetsService = TargetsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(target_entity_1.Target)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], TargetsService);
//# sourceMappingURL=targets.service.js.map