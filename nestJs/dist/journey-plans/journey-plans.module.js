"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.JourneyPlansModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const journey_plans_controller_1 = require("./journey-plans.controller");
const journey_plans_service_1 = require("./journey-plans.service");
const journey_plan_entity_1 = require("./entities/journey-plan.entity");
let JourneyPlansModule = class JourneyPlansModule {
};
exports.JourneyPlansModule = JourneyPlansModule;
exports.JourneyPlansModule = JourneyPlansModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([journey_plan_entity_1.JourneyPlan])],
        controllers: [journey_plans_controller_1.JourneyPlansController],
        providers: [journey_plans_service_1.JourneyPlansService],
        exports: [journey_plans_service_1.JourneyPlansService],
    })
], JourneyPlansModule);
//# sourceMappingURL=journey-plans.module.js.map