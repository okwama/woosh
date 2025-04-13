# Whoosh Code Index

## Application Structure

### Core Files
- `lib/main.dart` - Application entry point, theme configuration, and route setup
- `lib/services/api_service.dart` - Comprehensive API service handling all backend communication

### Models
- `lib/models/journeyplan_model.dart` - Journey plan data model with check-in/check-out functionality
- `lib/models/outlet_model.dart` - Outlet/premise data model
- `lib/models/user_model.dart` - User authentication and profile data
- `lib/models/order_model.dart` - Order management data
- `lib/models/leave_model.dart` - Leave application system
- `lib/models/target_model.dart` - Sales and visit targets tracking
- `lib/models/noticeboard_model.dart` - Notice board system
- `lib/models/product_model.dart` - Product catalog data

### Controllers
- `lib/controllers/auth_controller.dart` - Authentication state management
- `lib/controllers/cart_controller.dart` - Shopping cart functionality
- `lib/controllers/profile_controller.dart` - User profile management

### Key Features

#### Check-in/Check-out System
- **Journey Plan Check-in**: `lib/pages/journeyplan/journeyview.dart`
  - Geofence validation to ensure guards are at the correct location
  - Status tracking (Pending → Checked In → In Progress → Completed)
  - Location data capture
  - Optional photo capture

- **Journey Plan Check-out**: `lib/pages/journeyplan/reports/reportMain_page.dart` and `lib/pages/journeyplan/reports/base_report_page.dart`
  - Captures checkout time
  - Records GPS coordinates
  - Updates journey plan status

#### Journey Plan Management
- Journey Plans List: `lib/pages/journeyplan/journeyplans_page.dart`
- Journey Plan View: `lib/pages/journeyplan/journeyview.dart`
- API Integration: `lib/services/api_service.dart` (createJourneyPlan, fetchJourneyPlans, updateJourneyPlan)

#### Reports
- Report Generation: `lib/pages/journeyplan/reports/` directory
- Report Submission: `lib/services/api_service.dart` (submitReport method)

#### Order Management
- Order Creation: `lib/services/api_service.dart` (createOrder method)
- Order Updates: `lib/services/api_service.dart` (updateOrder method)
- Order Listing: `lib/services/api_service.dart` (getOrders method)

#### Leave Management
- Leave Application: `lib/services/api_service.dart` (submitLeaveApplication method)
- Leave Status Updates: `lib/services/api_service.dart` (updateLeaveStatus method)
- Leave History: `lib/services/api_service.dart` (getUserLeaves, getAllLeaves methods)

#### Target Tracking
- Target Setting: `lib/services/api_service.dart` (createTarget method)
- Target Progress: `lib/services/api_service.dart` (updateTargetProgress method)
- Target Listing: `lib/services/api_service.dart` (getTargets method)

#### Image Handling
- Cross-platform Image Upload: `lib/services/image_upload.dart`
- Platform-specific implementations:
  - Web: `lib/services/image_upload_web.dart`
  - Mobile/Desktop: `lib/services/image_upload_io.dart`

#### Authentication
- Login: `lib/services/api_service.dart` (login method)
- Logout: `lib/services/api_service.dart` (logout method)
- Profile Management: `lib/services/api_service.dart` (getProfile, updateProfile methods)

#### Connectivity
- Network Error Handling: `lib/services/api_service.dart` (handleNetworkError method)
- Offline Fallback: Mock data generation for development

## API Services
The application uses a RESTful API architecture with the following main endpoints:

- Authentication: `/api/auth/login`
- Journey Plans: `/api/journey-plans`
- Outlets: `/api/outlets`
- Orders: `/api/orders`
- Products: `/api/products`
- Leave: `/api/leave`
- Reports: `/api/reports`
- Targets: `/api/targets`
- Profile: `/api/profile`
- Notice Board: `/api/notice-board`

## Data Caching
- API response caching system implemented in `lib/services/api_service.dart` (ApiCache class)
- Cache validity duration: 5 minutes

## UI Components
- Custom theme configuration in `lib/main.dart`
- Consistent color scheme:
  - Primary: Gold (#DAA520)
  - Secondary: Black
  - Background: Light gray (#FBFAF9)
  - Surface: White
- Typography using Google Fonts (Quicksand) 