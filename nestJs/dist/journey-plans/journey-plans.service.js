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
exports.JourneyPlansService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const journey_plan_entity_1 = require("./entities/journey-plan.entity");
let JourneyPlansService = class JourneyPlansService {
    constructor(journeyPlanRepository) {
        this.journeyPlanRepository = journeyPlanRepository;
    }
    async create(createJourneyPlanDto) {
        const journeyPlan = this.journeyPlanRepository.create(createJourneyPlanDto);
        return this.journeyPlanRepository.save(journeyPlan);
    }
    async findAll() {
        return this.journeyPlanRepository.find({
            relations: ['user', 'client'],
        });
    }
    async findOne(id) {
        return this.journeyPlanRepository.findOne({
            where: { id },
            relations: ['user', 'client'],
        });
    }
    async update(id, updateJourneyPlanDto) {
        await this.journeyPlanRepository.update(id, updateJourneyPlanDto);
        return this.findOne(id);
    }
    async remove(id) {
        await this.journeyPlanRepository.delete(id);
    }
};
exports.JourneyPlansService = JourneyPlansService;
exports.JourneyPlansService = JourneyPlansService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(journey_plan_entity_1.JourneyPlan)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], JourneyPlansService);
//# sourceMappingURL=journey-plans.service.js.map