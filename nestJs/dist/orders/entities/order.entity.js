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
exports.Order = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("../../users/entities/user.entity");
const client_entity_1 = require("../../clients/entities/client.entity");
const order_item_entity_1 = require("./order-item.entity");
let Order = class Order {
};
exports.Order = Order;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)(),
    __metadata("design:type", Number)
], Order.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'totalAmount', type: 'double' }),
    __metadata("design:type", Number)
], Order.prototype, "totalAmount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'totalCost', type: 'decimal', precision: 11, scale: 2 }),
    __metadata("design:type", Number)
], Order.prototype, "totalCost", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'amountPaid', type: 'decimal', precision: 11, scale: 2 }),
    __metadata("design:type", Number)
], Order.prototype, "amountPaid", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 11, scale: 2 }),
    __metadata("design:type", Number)
], Order.prototype, "balance", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191 }),
    __metadata("design:type", String)
], Order.prototype, "comment", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'customerType', length: 191 }),
    __metadata("design:type", String)
], Order.prototype, "customerType", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'customerId', length: 191 }),
    __metadata("design:type", String)
], Order.prototype, "customerId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'customerName', length: 191 }),
    __metadata("design:type", String)
], Order.prototype, "customerName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'orderDate', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], Order.prototype, "orderDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'riderId', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], Order.prototype, "riderId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'riderName', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "riderName", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], Order.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'approvedTime', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "approvedTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'dispatchTime', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "dispatchTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'deliveryLocation', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "deliveryLocation", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'complete_latitude', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "completeLatitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'complete_longitude', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "completeLongitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'complete_address', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "completeAddress", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'pickupTime', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "pickupTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'deliveryTime', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "deliveryTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cancel_reason', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "cancelReason", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "recepient", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'userId', type: 'int' }),
    __metadata("design:type", Number)
], Order.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User),
    (0, typeorm_1.JoinColumn)({ name: 'userId' }),
    __metadata("design:type", user_entity_1.User)
], Order.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'clientId', type: 'int' }),
    __metadata("design:type", Number)
], Order.prototype, "clientId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => client_entity_1.Client),
    (0, typeorm_1.JoinColumn)({ name: 'clientId' }),
    __metadata("design:type", client_entity_1.Client)
], Order.prototype, "client", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'countryId', type: 'int' }),
    __metadata("design:type", Number)
], Order.prototype, "countryId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'regionId', type: 'int' }),
    __metadata("design:type", Number)
], Order.prototype, "regionId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'approved_by', length: 200 }),
    __metadata("design:type", String)
], Order.prototype, "approvedBy", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'approved_by_name', length: 200 }),
    __metadata("design:type", String)
], Order.prototype, "approvedByName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'storeId', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], Order.prototype, "storeId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'retail_manager', type: 'int' }),
    __metadata("design:type", Number)
], Order.prototype, "retailManager", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'key_channel_manager', type: 'int' }),
    __metadata("design:type", Number)
], Order.prototype, "keyChannelManager", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'distribution_manager', type: 'int' }),
    __metadata("design:type", Number)
], Order.prototype, "distributionManager", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'imageUrl', length: 191, nullable: true }),
    __metadata("design:type", String)
], Order.prototype, "imageUrl", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => order_item_entity_1.OrderItem, orderItem => orderItem.order),
    __metadata("design:type", Array)
], Order.prototype, "orderItems", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'createdAt', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], Order.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updatedAt', type: 'datetime', precision: 3 }),
    __metadata("design:type", Date)
], Order.prototype, "updatedAt", void 0);
exports.Order = Order = __decorate([
    (0, typeorm_1.Entity)('MyOrder')
], Order);
//# sourceMappingURL=order.entity.js.map