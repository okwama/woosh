# Woosh NestJS Backend

A NestJS backend server designed to work with the `citlogis_ws` database schema, providing direct database service calls for the Woosh Flutter application.

## Features

- **Authentication**: JWT-based authentication using the `SalesRep` table
- **User Management**: Sales representative management with role-based access
- **Client Management**: Full CRUD operations with search and location-based queries
- **Product Management**: Product catalog with pricing and stock management
- **Order Management**: Order processing with items and status tracking
- **Target Management**: Sales targets and achievement tracking
- **Journey Plans**: Route planning and check-in/check-out functionality
- **Notice Board**: Company announcements and notifications

## Database Schema

This backend is designed to work with the `citlogis_ws` database which includes:

- **SalesRep**: Main user table for sales representatives
- **Clients**: Customer/client information with location data
- **Product**: Product catalog with pricing
- **MyOrder**: Order management with status tracking
- **OrderItem**: Order line items
- **Target**: Sales targets and achievements
- **JourneyPlan**: Route planning and visit tracking
- **NoticeBoard**: Company announcements

## Installation

1. **Clone the repository**
   ```bash
   cd nestJs
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Environment Setup**
   ```bash
   cp env.example .env
   ```
   
   Update the `.env` file with your database credentials:
   ```env
   DB_HOST=localhost
   DB_PORT=3306
   DB_USERNAME=your_username
   DB_PASSWORD=your_password
   DB_DATABASE=citlogis_ws
   JWT_SECRET=your-super-secret-jwt-key-here
   ```

4. **Database Setup**
   - Ensure your MySQL server is running
   - Import the `citlogis_ws (1).sql` file into your database
   - The database should be named `citlogis_ws`

5. **Run the application**
   ```bash
   # Development
   npm run start:dev
   
   # Production
   npm run build
   npm run start:prod
   ```

## API Endpoints

### Authentication
- `POST /auth/login` - User login (email/password)
- `GET /auth/profile` - Get user profile (protected)
- `POST /auth/logout` - User logout (protected)

### Users (Sales Representatives)
- `GET /users` - Get all active users
- `GET /users/:id` - Get user by ID
- `POST /users` - Create new user
- `PATCH /users/:id` - Update user
- `DELETE /users/:id` - Soft delete user

### Clients
- `GET /clients` - Get all active clients
- `GET /clients/search` - Search clients with filters
- `GET /clients/stats` - Get client statistics
- `GET /clients/country/:countryId` - Get clients by country
- `GET /clients/region/:regionId` - Get clients by region
- `GET /clients/route/:routeId` - Get clients by route
- `GET /clients/location` - Find clients by location (latitude/longitude)
- `GET /clients/:id` - Get client by ID
- `POST /clients` - Create new client
- `PATCH /clients/:id` - Update client
- `DELETE /clients/:id` - Soft delete client

### Products
- `GET /products` - Get all products
- `GET /products/:id` - Get product by ID
- `POST /products` - Create new product
- `PATCH /products/:id` - Update product
- `DELETE /products/:id` - Delete product

### Orders
- `GET /orders` - Get all orders
- `GET /orders/:id` - Get order by ID
- `POST /orders` - Create new order
- `PATCH /orders/:id` - Update order
- `DELETE /orders/:id` - Delete order

### Targets
- `GET /targets` - Get all targets
- `GET /targets/:id` - Get target by ID
- `POST /targets` - Create new target
- `PATCH /targets/:id` - Update target
- `DELETE /targets/:id` - Delete target

### Journey Plans
- `GET /journey-plans` - Get all journey plans
- `GET /journey-plans/:id` - Get journey plan by ID
- `POST /journey-plans` - Create new journey plan
- `PATCH /journey-plans/:id` - Update journey plan
- `DELETE /journey-plans/:id` - Delete journey plan

### Notices
- `GET /notices` - Get all notices
- `GET /notices/:id` - Get notice by ID
- `POST /notices` - Create new notice
- `PATCH /notices/:id` - Update notice
- `DELETE /notices/:id` - Delete notice

## Authentication

The application uses JWT tokens for authentication. Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

## Database Direct Service Calls

This backend is designed to work with direct database service calls rather than external APIs, as per the project requirements. All operations are performed directly against the `citlogis_ws` database.

## Development

### Project Structure
```
src/
├── auth/           # Authentication module
├── users/          # Sales representatives management
├── clients/        # Client management
├── products/       # Product catalog
├── orders/         # Order management
├── targets/        # Sales targets
├── journey-plans/  # Route planning
├── notices/        # Notice board
└── config/         # Configuration files
```

### Adding New Features

1. Create a new module directory
2. Define the entity matching the database table
3. Create DTOs for data validation
4. Implement service with business logic
5. Create controller with endpoints
6. Add the module to `app.module.ts`

## Production Deployment

1. Set `NODE_ENV=production`
2. Set `DB_SYNC=false` to prevent automatic schema changes
3. Use a strong JWT secret
4. Configure proper database credentials
5. Set up reverse proxy (nginx) if needed
6. Use PM2 or similar process manager

## Troubleshooting

- **Database Connection Issues**: Verify database credentials and ensure MySQL is running
- **JWT Issues**: Check JWT secret configuration
- **Entity Issues**: Ensure entity definitions match the actual database schema
- **CORS Issues**: Configure CORS settings in main.ts if needed

## License

This project is part of the Woosh application suite. 