# Woosh - Field Sales Management Application

## Overview

Woosh is a comprehensive Flutter-based field sales management application designed for sales representatives, managers, and businesses to efficiently manage client relationships, orders, journey planning, and field operations. The application supports both online and offline functionality to ensure productivity regardless of connectivity.

## 🚀 Key Features

### 🔐 Authentication & User Management
- **Progressive Login System** - Multi-step authentication with token refresh
- **Secure Session Management** - JWT-based authentication with automatic refresh
- **User Profile Management** - Comprehensive profile settings and statistics
- **Account Security** - Password change, account deletion, and session history

### 🗺️ Journey Planning & Route Management
- **Smart Route Planning** - Create optimized journey plans with multiple client visits
- **Real-time Tracking** - GPS-based location tracking and check-in/check-out
- **Visit Management** - Schedule and manage client visits with reporting
- **Offline Journey Sync** - Continue operations without internet connectivity

### 👥 Client & Customer Management
- **Client Database** - Comprehensive client information and contact management
- **Client Stock Management** - Track and manage client inventory levels
- **Payment Processing** - Handle client payments and payment history
- **Client Analytics** - Generate reports on client interactions and performance

### 📦 Order & Inventory Management
- **Product Catalog** - Browse and search extensive product database
- **Shopping Cart** - Add products with pricing options and bulk ordering
- **Order Processing** - Create, edit, and track order status
- **Inventory Tracking** - Real-time stock levels and availability

### 💰 Point of Sale (POS) System
- **Uplift Sales** - Process direct sales transactions
- **Multiple Payment Methods** - Support for various payment options
- **Receipt Generation** - Digital receipts and transaction records
- **Sales Reporting** - Track and analyze sales performance

### 📋 Task & Leave Management
- **Task Assignment** - Create and manage field tasks
- **Task Tracking** - Monitor task progress and completion
- **Leave Applications** - Submit and manage leave requests
- **Approval Workflows** - Streamlined approval processes

### 📊 Reporting & Analytics
- **Feedback Reports** - Collect and analyze client feedback
- **Product Reports** - Track product performance and visibility
- **Sales Analytics** - Comprehensive sales performance metrics
- **Visual Dashboards** - Interactive charts and graphs

### 🔄 Offline-First Architecture
- **Data Synchronization** - Automatic sync when connectivity returns
- **Local Storage** - Hive-based local database for offline operations
- **Conflict Resolution** - Intelligent handling of data conflicts
- **Background Sync** - Seamless background data synchronization

## 📱 Platform Support

- **Android** - Native Android application
- **iOS** - Native iOS application  
- **Web** - Progressive Web Application (PWA)
- **Desktop** - Windows, macOS, and Linux support

## 🛠️ Technical Architecture

### Frontend
- **Flutter** - Cross-platform UI framework
- **GetX** - State management and navigation
- **Hive** - Local database for offline storage
- **Dio** - HTTP client for API communication

### Backend Integration
- **RESTful APIs** - Integration with Node.js backend
- **JWT Authentication** - Secure token-based authentication
- **File Upload** - Image and document upload capabilities
- **Real-time Updates** - Live data synchronization

## 📚 Documentation Structure

### User Guides
- [Authentication System](docs/authentication_system.md) - Login, signup, and security features
- [Journey Planning Guide](docs/journey_planning_guide.md) - Route planning and visit management
- [Client Management Guide](docs/client_management_guide.md) - Customer relationship management
- [Order Management Guide](docs/order_management_guide.md) - Product ordering and inventory
- [POS System Guide](docs/pos_system_guide.md) - Point of sale operations
- [Task Management Guide](docs/task_management_guide.md) - Task assignment and tracking
- [Profile Management Guide](docs/profile_management_guide.md) - User account and settings
- [Leave Management Guide](docs/leave_management_guide.md) - Leave applications and approvals
- [Offline Features Guide](docs/offline_features_guide.md) - Working without internet

### Technical Documentation
- [API Documentation](docs/api_documentation.md) - Service architecture and endpoints
- [Database Schema](docs/database_schema.md) - Data models and relationships
- [Security Implementation](docs/security_implementation.md) - Authentication and data protection
- [Deployment Guide](docs/deployment_guide.md) - Installation and configuration

### User Flows
- [Complete User Flows](docs/user_flows.md) - Visual representation of all user journeys
- [Quick Start Guide](docs/quick_start_guide.md) - Getting started with the application

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.6.0)
- Dart SDK
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-repo/woosh.git
   cd woosh
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   - Set up API endpoints in configuration files
   - Configure authentication credentials
   - Set up local storage permissions

4. **Run the application**
   ```bash
   flutter run
   ```

### Build for Production

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## 🔧 Configuration

### Environment Variables
- `API_BASE_URL` - Backend API endpoint
- `STORAGE_ENCRYPTION_KEY` - Local storage encryption
- `APP_VERSION` - Application version identifier

### Features Configuration
- Authentication settings in `lib/config/auth_config.dart`
- API endpoints in `lib/config/api_config.dart`
- Theme customization in `lib/utils/app_theme.dart`

## 📊 Performance & Analytics

- **Offline-first design** - Works seamlessly without internet
- **Optimized for mobile** - Battery and data usage optimization
- **Real-time sync** - Immediate updates when online
- **Comprehensive logging** - Detailed error tracking and analytics

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is proprietary software. All rights reserved.

## 📞 Support

For support and questions:
- **Email**: support@wooshapp.com
- **Documentation**: [Complete Documentation](docs/)
- **Issue Tracker**: GitHub Issues

---

**Version**: 1.0.7+1  
**Last Updated**: December 2024  
**Platforms**: Android, iOS, Web, Desktop
