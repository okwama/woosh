import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { User } from '../users/entities/user.entity';
import { Client } from '../clients/entities/client.entity';
import { Product } from '../products/entities/product.entity';
import { Order } from '../orders/entities/order.entity';
import { OrderItem } from '../orders/entities/order-item.entity';
import { Target } from '../targets/entities/target.entity';
import { JourneyPlan } from '../journey-plans/entities/journey-plan.entity';
import { Notice } from '../notices/entities/notice.entity';

export const getDatabaseConfig = (configService: ConfigService): TypeOrmModuleOptions => {
  // Check if we should use local SQLite for development
  const useLocalDb = configService.get<boolean>('USE_LOCAL_DB', false);
  
  if (useLocalDb) {
    console.log('🔧 Using local SQLite database for development');
    return {
      type: 'sqlite',
      database: './woosh-dev.db',
      entities: [
        User,
        Client,
        Product,
        Order,
        OrderItem,
        Target,
        JourneyPlan,
        Notice,
      ],
      synchronize: true, // Auto-create tables for development
      logging: true,
    };
  }

  // Check if DATABASE_URL is provided
  const databaseUrl = configService.get<string>('DATABASE_URL');
  
  if (databaseUrl) {
    // Parse DATABASE_URL
    const url = new URL(databaseUrl);
    return {
      type: 'mysql',
      host: url.hostname,
      port: parseInt(url.port) || 3306,
      username: url.username,
      password: url.password,
      database: url.pathname.substring(1), // Remove leading slash
      entities: [
        User,
        Client,
        Product,
        Order,
        OrderItem,
        Target,
        JourneyPlan,
        Notice,
      ],
      synchronize: configService.get<boolean>('DB_SYNC', false),
      logging: configService.get<boolean>('DB_LOGGING', false),
      charset: 'utf8mb4',
      ssl: configService.get<boolean>('DB_SSL', false),
      extra: {
        connectionLimit: 10
      },
    };
  }

  // Use individual parameters
  return {
    type: 'mysql',
    host: configService.get<string>('DB_HOST', 'localhost'),
    port: configService.get<number>('DB_PORT', 3306),
    username: configService.get<string>('DB_USERNAME', 'root'),
    password: configService.get<string>('DB_PASSWORD', ''),
    database: configService.get<string>('DB_DATABASE', 'citlogis_ws'),
    entities: [
      User,
      Client,
      Product,
      Order,
      OrderItem,
      Target,
      JourneyPlan,
      Notice,
    ],
    synchronize: configService.get<boolean>('DB_SYNC', false),
    logging: configService.get<boolean>('DB_LOGGING', false),
    charset: 'utf8mb4',
    ssl: configService.get<boolean>('DB_SSL', false),
    extra: {
      connectionLimit: 10
    },
  };
}; 