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
Object.defineProperty(exports, "__esModule", { value: true });
exports.JourneyPlan = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("../../users/entities/user.entity");
const client_entity_1 = require("../../clients/entities/client.entity");
let JourneyPlan = class JourneyPlan {
};
exports.JourneyPlan = JourneyPlan;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], JourneyPlan.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], JourneyPlan.prototype, "date", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191 }),
    __metadata("design:type", String)
], JourneyPlan.prototype, "time", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'userId', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], JourneyPlan.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'userId' }),
    __metadata("design:type", user_entity_1.User)
], JourneyPlan.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'clientId', type: 'int' }),
    __metadata("design:type", Number)
], JourneyPlan.prototype, "clientId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => client_entity_1.Client),
    (0, typeorm_1.JoinColumn)({ name: 'clientId' }),
    __metadata("design:type", client_entity_1.Client)
], JourneyPlan.prototype, "client", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], JourneyPlan.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'checkInTime', type: 'datetime', precision: 3, nullable: true }),
    __metadata("design:type", Date)
], JourneyPlan.prototype, "checkInTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'double', nullable: true }),
    __metadata("design:type", Number)
], JourneyPlan.prototype, "latitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'double', nullable: true }),
    __metadata("design:type", Number)
], JourneyPlan.prototype, "longitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'imageUrl', length: 191, nullable: true }),
    __metadata("design:type", String)
], JourneyPlan.prototype, "imageUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191, nullable: true }),
    __metadata("design:type", String)
], JourneyPlan.prototype, "notes", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'double', nullable: true }),
    __metadata("design:type", Number)
], JourneyPlan.prototype, "checkoutLatitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'double', nullable: true }),
    __metadata("design:type", Number)
], JourneyPlan.prototype, "checkoutLongitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'checkoutTime', type: 'datetime', precision: 3, nullable: true }),
    __metadata("design:type", Date)
], JourneyPlan.prototype, "checkoutTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'showUpdateLocation', type: 'tinyint', default: 1 }),
    __metadata("design:type", Boolean)
], JourneyPlan.prototype, "showUpdateLocation", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'routeId', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], JourneyPlan.prototype, "routeId", void 0);
exports.JourneyPlan = JourneyPlan = __decorate([
    (0, typeorm_1.Entity)('JourneyPlan')
], JourneyPlan);
//# sourceMappingURL=journey-plan.entity.js.map