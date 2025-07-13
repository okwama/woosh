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
exports.Client = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("../../users/entities/user.entity");
let Client = class Client {
};
exports.Client = Client;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], Client.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191 }),
    __metadata("design:type", String)
], Client.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191, nullable: true }),
    __metadata("design:type", String)
], Client.prototype, "address", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'double', nullable: true }),
    __metadata("design:type", Number)
], Client.prototype, "latitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'double', nullable: true }),
    __metadata("design:type", Number)
], Client.prototype, "longitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 11, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], Client.prototype, "balance", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191, nullable: true }),
    __metadata("design:type", String)
], Client.prototype, "email", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'region_id', type: 'int' }),
    __metadata("design:type", Number)
], Client.prototype, "regionId", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191 }),
    __metadata("design:type", String)
], Client.prototype, "region", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'route_id', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], Client.prototype, "routeId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'route_name', length: 191, nullable: true }),
    __metadata("design:type", String)
], Client.prototype, "routeName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'route_id_update', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], Client.prototype, "routeIdUpdate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'route_name_update', length: 100, nullable: true }),
    __metadata("design:type", String)
], Client.prototype, "routeNameUpdate", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191 }),
    __metadata("design:type", String)
], Client.prototype, "contact", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'tax_pin', length: 191, nullable: true }),
    __metadata("design:type", String)
], Client.prototype, "taxPin", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191, nullable: true }),
    __metadata("design:type", String)
], Client.prototype, "location", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], Client.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'client_type', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], Client.prototype, "clientType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'outlet_account', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], Client.prototype, "outletAccount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'countryId', type: 'int' }),
    __metadata("design:type", Number)
], Client.prototype, "countryId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'added_by', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], Client.prototype, "addedBy", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'added_by' }),
    __metadata("design:type", user_entity_1.User)
], Client.prototype, "addedByUser", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], Client.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updatedAt', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], Client.prototype, "updatedAt", void 0);
exports.Client = Client = __decorate([
    (0, typeorm_1.Entity)('Clients')
], Client);
//# sourceMappingURL=client.entity.js.map