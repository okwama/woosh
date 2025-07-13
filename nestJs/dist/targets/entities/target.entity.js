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
exports.Target = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("../../users/entities/user.entity");
let Target = class Target {
};
exports.Target = Target;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], Target.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'salesRepId', type: 'int' }),
    __metadata("design:type", Number)
], Target.prototype, "salesRepId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User),
    (0, typeorm_1.JoinColumn)({ name: 'salesRepId' }),
    __metadata("design:type", user_entity_1.User)
], Target.prototype, "salesRep", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'isCurrent', type: 'tinyint', default: 0 }),
    __metadata("design:type", Boolean)
], Target.prototype, "isCurrent", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'targetValue', type: 'int' }),
    __metadata("design:type", Number)
], Target.prototype, "targetValue", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'achievedValue', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], Target.prototype, "achievedValue", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'tinyint', default: 0 }),
    __metadata("design:type", Boolean)
], Target.prototype, "achieved", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'createdAt', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], Target.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updatedAt', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], Target.prototype, "updatedAt", void 0);
exports.Target = Target = __decorate([
    (0, typeorm_1.Entity)('Target')
], Target);
//# sourceMappingURL=target.entity.js.map