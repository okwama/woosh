"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const jwt_1 = require("@nestjs/jwt");
const passport_1 = require("@nestjs/passport");
const database_config_1 = require("./config/database.config");
const auth_module_1 = require("./auth/auth.module");
const users_module_1 = require("./users/users.module");
const clients_module_1 = require("./clients/clients.module");
const products_module_1 = require("./products/products.module");
const orders_module_1 = require("./orders/orders.module");
const targets_module_1 = require("./targets/targets.module");
const journey_plans_module_1 = require("./journey-plans/journey-plans.module");
const notices_module_1 = require("./notices/notices.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({
                isGlobal: true,
                envFilePath: ['.env.local', '.env'],
            }),
            typeorm_1.TypeOrmModule.forRootAsync({
                imports: [config_1.ConfigModule],
                useFactory: (configService) => (0, database_config_1.getDatabaseConfig)(configService),
                inject: [config_1.ConfigService],
            }),
            jwt_1.JwtModule.registerAsync({
                imports: [config_1.ConfigModule],
                useFactory: (configService) => ({
                    secret: configService.get('JWT_SECRET', 'woosh-secret-key'),
                    signOptions: { expiresIn: '9h' },
                }),
                inject: [config_1.ConfigService],
            }),
            passport_1.PassportModule,
            auth_module_1.AuthModule,
            users_module_1.UsersModule,
            clients_module_1.ClientsModule,
            products_module_1.ProductsModule,
            orders_module_1.OrdersModule,
            targets_module_1.TargetsModule,
            journey_plans_module_1.JourneyPlansModule,
            notices_module_1.NoticesModule,
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map