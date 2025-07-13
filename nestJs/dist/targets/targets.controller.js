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
exports.TargetsController = void 0;
const common_1 = require("@nestjs/common");
const targets_service_1 = require("./targets.service");
const create_target_dto_1 = require("./dto/create-target.dto");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
let TargetsController = class TargetsController {
    constructor(targetsService) {
        this.targetsService = targetsService;
    }
    create(createTargetDto) {
        return this.targetsService.create(createTargetDto);
    }
    findAll() {
        return this.targetsService.findAll();
    }
    findOne(id) {
        return this.targetsService.findOne(+id);
    }
    update(id, updateTargetDto) {
        return this.targetsService.update(+id, updateTargetDto);
    }
    remove(id) {
        return this.targetsService.remove(+id);
    }
};
exports.TargetsController = TargetsController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_target_dto_1.CreateTargetDto]),
    __metadata("design:returntype", void 0)
], TargetsController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], TargetsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TargetsController.prototype, "findOne", null);
__decorate([
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TargetsController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TargetsController.prototype, "remove", null);
exports.TargetsController = TargetsController = __decorate([
    (0, common_1.Controller)('targets'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [targets_service_1.TargetsService])
], TargetsController);
//# sourceMappingURL=targets.controller.js.map