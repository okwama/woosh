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
exports.User = exports.UserRole = void 0;
const typeorm_1 = require("typeorm");
const class_transformer_1 = require("class-transformer");
const bcrypt = require("bcryptjs");
var UserRole;
(function (UserRole) {
    UserRole["ADMIN"] = "admin";
    UserRole["USER"] = "USER";
    UserRole["MANAGER"] = "manager";
    UserRole["RIDER"] = "rider";
})(UserRole || (exports.UserRole = UserRole = {}));
let User = class User {
    async hashPassword() {
        if (this.password) {
            this.password = await bcrypt.hash(this.password, 12);
        }
    }
    async validatePassword(password) {
        return bcrypt.compare(password, this.password);
    }
    get fullName() {
        return this.name || '';
    }
};
exports.User = User;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], User.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191 }),
    __metadata("design:type", String)
], User.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true, length: 191 }),
    __metadata("design:type", String)
], User.prototype, "email", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'phoneNumber', length: 191 }),
    __metadata("design:type", String)
], User.prototype, "phone", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191 }),
    (0, class_transformer_1.Exclude)(),
    __metadata("design:type", String)
], User.prototype, "password", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'countryId', type: 'int' }),
    __metadata("design:type", Number)
], User.prototype, "countryId", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191 }),
    __metadata("design:type", String)
], User.prototype, "country", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'region_id', type: 'int' }),
    __metadata("design:type", Number)
], User.prototype, "regionId", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191 }),
    __metadata("design:type", String)
], User.prototype, "region", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'route_id', type: 'int' }),
    __metadata("design:type", Number)
], User.prototype, "routeId", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 100 }),
    __metadata("design:type", String)
], User.prototype, "route", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'route_id_update', type: 'int' }),
    __metadata("design:type", Number)
], User.prototype, "routeIdUpdate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'route_name_update', length: 100 }),
    __metadata("design:type", String)
], User.prototype, "routeNameUpdate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'visits_targets', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], User.prototype, "visitsTargets", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'new_clients', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], User.prototype, "newClients", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'vapes_targets', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], User.prototype, "vapesTargets", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'pouches_targets', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], User.prototype, "pouchesTargets", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191, default: 'USER' }),
    __metadata("design:type", String)
], User.prototype, "role", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'manager_type', type: 'int' }),
    __metadata("design:type", Number)
], User.prototype, "managerType", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], User.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'retail_manager', type: 'int' }),
    __metadata("design:type", Number)
], User.prototype, "retailManager", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'key_channel_manager', type: 'int' }),
    __metadata("design:type", Number)
], User.prototype, "keyChannelManager", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'distribution_manager', type: 'int' }),
    __metadata("design:type", Number)
], User.prototype, "distributionManager", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'photoUrl', length: 191, default: '' }),
    __metadata("design:type", String)
], User.prototype, "photoUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'managerId', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], User.prototype, "managerId", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'createdAt', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], User.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updatedAt', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], User.prototype, "updatedAt", void 0);
__decorate([
    (0, typeorm_1.BeforeInsert)(),
    (0, typeorm_1.BeforeUpdate)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], User.prototype, "hashPassword", null);
exports.User = User = __decorate([
    (0, typeorm_1.Entity)('SalesRep')
], User);
//# sourceMappingURL=user.entity.js.map