"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDatabaseConfig = void 0;
const user_entity_1 = require("../users/entities/user.entity");
const client_entity_1 = require("../clients/entities/client.entity");
const product_entity_1 = require("../products/entities/product.entity");
const order_entity_1 = require("../orders/entities/order.entity");
const order_item_entity_1 = require("../orders/entities/order-item.entity");
const target_entity_1 = require("../targets/entities/target.entity");
const journey_plan_entity_1 = require("../journey-plans/entities/journey-plan.entity");
const notice_entity_1 = require("../notices/entities/notice.entity");
const getDatabaseConfig = (configService) => {
    const useLocalDb = configService.get('USE_LOCAL_DB', false);
    if (useLocalDb) {
        console.log('🔧 Using local SQLite database for development');
        return {
            type: 'sqlite',
            database: './woosh-dev.db',
            entities: [
                user_entity_1.User,
                client_entity_1.Client,
                product_entity_1.Product,
                order_entity_1.Order,
                order_item_entity_1.OrderItem,
                target_entity_1.Target,
                journey_plan_entity_1.JourneyPlan,
                notice_entity_1.Notice,
            ],
            synchronize: true,
            logging: true,
        };
    }
    const databaseUrl = configService.get('DATABASE_URL');
    if (databaseUrl) {
        const url = new URL(databaseUrl);
        return {
            type: 'mysql',
            host: url.hostname,
            port: parseInt(url.port) || 3306,
            username: url.username,
            password: url.password,
            database: url.pathname.substring(1),
            entities: [
                user_entity_1.User,
                client_entity_1.Client,
                product_entity_1.Product,
                order_entity_1.Order,
                order_item_entity_1.OrderItem,
                target_entity_1.Target,
                journey_plan_entity_1.JourneyPlan,
                notice_entity_1.Notice,
            ],
            synchronize: configService.get('DB_SYNC', false),
            logging: configService.get('DB_LOGGING', false),
            charset: 'utf8mb4',
            ssl: configService.get('DB_SSL', false),
            extra: {
                connectionLimit: 10
            },
        };
    }
    return {
        type: 'mysql',
        host: configService.get('DB_HOST', 'localhost'),
        port: configService.get('DB_PORT', 3306),
        username: configService.get('DB_USERNAME', 'root'),
        password: configService.get('DB_PASSWORD', ''),
        database: configService.get('DB_DATABASE', 'citlogis_ws'),
        entities: [
            user_entity_1.User,
            client_entity_1.Client,
            product_entity_1.Product,
            order_entity_1.Order,
            order_item_entity_1.OrderItem,
            target_entity_1.Target,
            journey_plan_entity_1.JourneyPlan,
            notice_entity_1.Notice,
        ],
        synchronize: configService.get('DB_SYNC', false),
        logging: configService.get('DB_LOGGING', false),
        charset: 'utf8mb4',
        ssl: configService.get('DB_SSL', false),
        extra: {
            connectionLimit: 10
        },
    };
};
exports.getDatabaseConfig = getDatabaseConfig;
//# sourceMappingURL=database.config.js.map