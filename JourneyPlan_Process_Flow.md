# JourneyPlan Process Flow - Complete Cycle

## Overview
JourneyPlan is a sales management system built with Flutter that manages field sales representative visits to clients. The system tracks the complete journey from planning to execution and reporting.

## Architecture
- **Frontend**: Flutter app with GetX state management
- **Backend**: Node.js API with REST endpoints
- **Database**: SQL database for persistent storage
- **Local Storage**: Hive for offline capabilities and caching
- **Authentication**: JWT token-based authentication

## Complete Process Flow

### 1. Application Initialization
```
main.dart
├── Initialize GetStorage
├── Initialize Hive (with error recovery)
├── Register Hive adapters (Client, Product, ProductReport models)
├── Initialize core services:
│   ├── AuthController
│   ├── UpliftCartController
│   ├── SharedDataService
│   ├── JourneyPlanStateService
│   ├── ClientHiveService
│   └── ProductReportHiveService
└── Initialize non-critical services in background:
    ├── EnhancedJourneyPlanService
    ├── OfflineSyncService
    ├── ProgressiveLoginService
    └── PermissionService
```

### 2. Authentication Flow
```
Login Process:
├── User enters phone number and password
├── TokenService validates credentials with API
├── On success:
│   ├── Store JWT tokens (access + refresh)
│   ├── Save user data to Hive
│   ├── AuthController updates state
│   └── Navigate to HomePage
└── On failure: Show error message
```

### 3. Home Dashboard
```
HomePage:
├── Check clock-in status (ClockInOutService)
├── Load dashboard metrics:
│   ├── Pending journey plans count
│   ├── Pending tasks count
│   └── Unread notices count
├── Display navigation menu:
│   ├── Journey Plans
│   ├── Clients
│   ├── Orders
│   ├── Profile/Targets
│   ├── Tasks
│   ├── Notice Board
│   └── Leave Applications
└── Background data refresh
```

### 4. Journey Plan Management

#### 4.1 Journey Plan Creation
```
CreateJourneyPlanPage:
├── Prerequisites:
│   ├── User must be clocked in (ClockInOutService)
│   └── Load available clients and routes
├── Client Selection:
│   ├── Search clients by name/address
│   ├── Smart filtering with relevance scoring
│   ├── Pagination support (20 clients per page)
│   └── Cache search results
├── Journey Planning:
│   ├── Select date/time
│   ├── Choose client
│   ├── Add optional notes
│   ├── Select route (if applicable)
│   └── Submit to API
├── Offline Support:
│   ├── If server error (500-503): Save to PendingJourneyPlanHiveService
│   ├── Sync when connection restored
│   └── Show appropriate feedback to user
└── Success: Navigate back to JourneyPlansPage
```

#### 4.2 Journey Plan Listing
```
JourneyPlansPage:
├── Data Loading:
│   ├── Preload clients and journey plans
│   ├── Use JourneyPlanStateService for caching
│   ├── Pagination support (20 plans per page)
│   └── Pull-to-refresh functionality
├── Filtering Options:
│   ├── Filter by status (Pending, Checked In, In Progress, Completed, Cancelled)
│   ├── Filter by date
│   └── Real-time search
├── Journey Plan Status:
│   ├── Pending (0) - Orange
│   ├── Checked In (1) - Blue
│   ├── In Progress (2) - Purple
│   ├── Completed (3) - Green
│   └── Cancelled (4) - Red
└── Actions:
    ├── Create new journey plan
    ├── View/edit existing plans
    └── Delete plans (if pending)
```

### 5. Journey Execution Flow

#### 5.1 Journey View & Check-in
```
JourneyView:
├── Location Services:
│   ├── Get current GPS position
│   ├── Calculate distance to client
│   ├── Geofencing validation (20,037,500m radius - global)
│   └── Reverse geocoding for address display
├── Check-in Process:
│   ├── Validate user is within geofence
│   ├── Capture photo (ImagePicker)
│   ├── Optimistic UI update (immediate status change)
│   ├── Navigate to ReportsOrdersPage
│   └── Background processing:
│       ├── Upload image to server
│       ├── Update journey plan status to "In Progress"
│       ├── Store GPS coordinates
│       └── Error handling with retry logic
└── Status Management:
    ├── Pending → Check-in available
    ├── Checked In → Redirect to reports
    ├── In Progress → Show reports
    └── Completed → Show completion status
```

#### 5.2 Reports & Data Collection
```
ReportsOrdersPage:
├── Required Reports:
│   ├── Product Availability Report (ProductReportPage)
│   ├── Feedback Report (FeedbackReportPage)
│   └── Visibility Report (VisibilityReportPage)
├── Optional Reports:
│   ├── Product Sample Report
│   └── Product Return Report
├── Report Submission:
│   ├── Each report saved independently
│   ├── Real-time validation
│   ├── Image uploads for evidence
│   ├── GPS coordinates captured
│   └── Offline support with Hive storage
├── Progress Tracking:
│   ├── Visual indicators for completed reports
│   ├── Prevent checkout until all required reports done
│   └── Cache submitted reports
└── Data Persistence:
    ├── ProductReportHiveService for offline storage
    ├── SharedDataService for caching
    └── Automatic sync when online
```

### 6. Journey Completion (Checkout)

#### 6.1 Checkout Process
```
Checkout Flow:
├── Prerequisites:
│   ├── All required reports completed
│   ├── Valid GPS location
│   └── Network connectivity
├── Confirmation Dialog:
│   ├── User confirms checkout intention
│   └── Warning about finality
├── Checkout Execution:
│   ├── Capture current GPS coordinates
│   ├── Record checkout timestamp
│   ├── Update journey status to "Completed"
│   ├── API call: JourneyPlanService.updateJourneyPlan()
│   └── Clear all local caches
├── Post-Checkout:
│   ├── Update JourneyPlanStateService
│   ├── Refresh dashboard metrics
│   ├── Show success message
│   └── Navigate back to journey list
└── Error Handling:
    ├── Network errors: Retry logic
    ├── Server errors: User feedback
    └── GPS errors: Fallback coordinates
```

### 7. Offline Capabilities

#### 7.1 Offline Sync Service
```
OfflineSyncService:
├── Connectivity Monitoring:
│   ├── Real-time network status tracking
│   ├── Automatic sync when connection restored
│   └── Background processing
├── Offline Operations:
│   ├── Journey plan creation (PendingJourneyPlanHiveService)
│   ├── Report submissions (ProductReportHiveService)
│   ├── Clock in/out sessions (PendingSessionHiveService)
│   └── Image uploads (queued for later)
├── Sync Strategy:
│   ├── FIFO queue for pending operations
│   ├── Exponential backoff for retries
│   ├── Conflict resolution
│   └── Data integrity checks
└── Cache Management:
    ├── Client data caching
    ├── Product information
    ├── Route information
    └── User preferences
```

### 8. State Management

#### 8.1 Core Controllers
```
State Management:
├── AuthController:
│   ├── User authentication state
│   ├── Session management
│   └── Role-based permissions
├── JourneyPlanStateService:
│   ├── Journey plan data caching
│   ├── Real-time status updates
│   ├── Pagination management
│   └── Filter state
├── SharedDataService:
│   ├── Cross-page data sharing
│   ├── API call optimization
│   ├── Cache management
│   └── Memory optimization
└── ClockInOutState:
    ├── Work session tracking
    ├── Time validation
    └── Attendance monitoring
```

### 9. Data Models

#### 9.1 Core Models
```
Data Structure:
├── JourneyPlan:
│   ├── id, date, time, status
│   ├── client (nested Client model)
│   ├── GPS coordinates (lat/lng)
│   ├── checkInTime, checkoutTime
│   ├── imageUrl, notes
│   ├── routeId, routeName
│   └── showUpdateLocation flag
├── Client:
│   ├── Basic info (id, name, phone, email)
│   ├── Address details
│   ├── GPS coordinates
│   ├── Business information
│   └── Route assignment
├── Report Models:
│   ├── ProductReport (availability, quantities)
│   ├── FeedbackReport (client feedback)
│   ├── VisibilityReport (brand visibility)
│   ├── ProductSampleReport (samples given)
│   └── ProductReturnReport (returns/exchanges)
└── Hive Models:
    ├── Offline-optimized versions
    ├── Sync status tracking
    └── Conflict resolution data
```

### 10. API Integration

#### 10.1 Service Layer
```
API Services:
├── JourneyPlanService:
│   ├── CRUD operations for journey plans
│   ├── Status updates (pending → checked_in → in_progress → completed)
│   ├── Location updates
│   └── Bulk operations
├── ReportService:
│   ├── Submit various report types
│   ├── Image upload handling
│   ├── Batch submissions
│   └── Validation
├── ClientService:
│   ├── Client data management
│   ├── Location updates
│   └── Search functionality
└── ApiService (Base):
    ├── Authentication headers
    ├── Token refresh logic
    ├── Error handling
    ├── Request/response logging
    └── Image upload utilities
```

### 11. Error Handling & Recovery

#### 11.1 Resilience Features
```
Error Handling:
├── Network Errors:
│   ├── Automatic retry with exponential backoff
│   ├── Offline mode activation
│   ├── Queue operations for later sync
│   └── User feedback with retry options
├── Authentication Errors:
│   ├── Automatic token refresh
│   ├── Progressive login service
│   ├── Session validation
│   └── Graceful logout
├── Location Errors:
│   ├── Permission handling
│   ├── GPS timeout management
│   ├── Fallback coordinates
│   └── Manual location entry
├── Server Errors:
│   ├── 500-503: Retry logic
│   ├── 404: Handle missing resources
│   ├── 401/403: Re-authentication
│   └── Rate limiting: Backoff strategy
└── Data Corruption:
    ├── Hive box recovery
    ├── Cache clearing
    ├── Fresh data reload
    └── User notification
```

### 12. Performance Optimizations

#### 12.1 Efficiency Features
```
Performance:
├── Caching Strategy:
│   ├── JourneyPlanStateService (10-minute cache)
│   ├── SharedDataService (cross-page caching)
│   ├── Client data caching
│   └── Product information caching
├── Pagination:
│   ├── 20 items per page default
│   ├── Infinite scroll loading
│   ├── Smart prefetching
│   └── Memory management
├── Image Optimization:
│   ├── Automatic compression (60% quality)
│   ├── Resize to 800x600 max
│   ├── Background uploads
│   └── Memory cleanup
├── Background Processing:
│   ├── Non-critical service initialization
│   ├── Offline sync operations
│   ├── Cache updates
│   └── Data preloading
└── UI Optimizations:
    ├── Optimistic UI updates
    ├── Shimmer loading effects
    ├── Debounced search
    └── Efficient rebuilds
```

## Key Workflows

### Typical Daily Workflow for Sales Rep:
1. **Morning**: Clock in via profile page
2. **Planning**: Create journey plans for client visits
3. **Travel**: Navigate to client locations
4. **Visit Execution**:
   - Check in at client location (with photo)
   - Complete required reports
   - Submit optional reports as needed
   - Check out to complete visit
5. **Evening**: Review completed visits and clock out

### Manager Oversight:
- Real-time tracking of sales rep locations
- Journey plan approval/monitoring
- Report analytics and insights
- Performance metrics tracking

## Technical Implementation Notes

### Security:
- JWT authentication with refresh tokens
- Role-based access control
- Secure API endpoints
- Local data encryption (Hive)

### Scalability:
- Pagination for large datasets
- Efficient caching mechanisms
- Background sync operations
- Memory management

### Reliability:
- Offline-first approach
- Automatic retry mechanisms
- Data integrity checks
- Graceful error handling

### User Experience:
- Optimistic UI updates
- Real-time feedback
- Intuitive navigation
- Responsive design

## Data Flow Summary
```
User → Authentication → Dashboard → Journey Planning → Client Visit → Check-in → Reports → Checkout → Sync → Dashboard
```

This cycle repeats for each client visit, with the system maintaining state across offline/online transitions and providing comprehensive tracking and reporting capabilities.