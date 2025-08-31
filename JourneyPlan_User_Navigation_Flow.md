# JourneyPlan User Navigation Flow

## Overview
This document outlines the user navigation flow for the JourneyPlan system, designed for implementation with the Repository Pattern. It focuses on screen transitions, user interactions, and navigation logic.

## Navigation Architecture

### Repository Pattern Integration
```
Presentation Layer (UI) → Use Cases → Repository Interface → Data Sources
```

## User Navigation Flow

### 1. App Launch & Authentication

#### 1.1 Initial Flow
```
App Launch
├── SplashScreen (2 seconds)
├── Check Authentication Status
│   ├── If Authenticated → HomePage
│   └── If Not Authenticated → LoginPage
```

#### 1.2 Login Navigation
```
LoginPage
├── Enter credentials (phone + password)
├── Validate → Loading state
├── Success → HomePage
└── Failure → Show error, stay on LoginPage
```

### 2. Main Dashboard Navigation

#### 2.1 HomePage Structure
```
HomePage (Main Dashboard)
├── Header: App title + sync indicators
├── User Profile Section:
│   ├── Name, phone, session status
│   └── Tap → ProfilePage
├── Navigation Grid (2x6):
│   ├── Journey Plans (session-restricted)
│   ├── View Clients
│   ├── Notice Board (with badge count)
│   ├── Add/Edit Orders
│   ├── View Orders
│   ├── Tasks/Warnings (with badge count)
│   ├── Leave Applications
│   ├── Uplift Sales
│   ├── Uplift Sales History
│   ├── Product Returns
│   ├── Asset Requests
│   └── [Future menu items]
```

#### 2.2 Session-Based Navigation
```
Journey Plans Access:
├── Check Clock Status
├── If Not Clocked In:
│   ├── Show "Session Required" dialog
│   ├── Option to navigate to ProfilePage
│   └── Auto-navigate to JourneyPlans after clock-in
└── If Clocked In:
    └── Navigate to JourneyPlansLoadingScreen
```

### 3. Journey Plan Navigation Flow

#### 3.1 Journey Plans List Navigation
```
JourneyPlansLoadingScreen
├── Preload data (clients + journey plans)
├── Show loading indicator
└── Navigate to JourneyPlansPage

JourneyPlansPage
├── Header: Search + Filter + Sort controls
├── Active Visit Banner (if exists)
├── Journey Plans List:
│   ├── Each item shows: Client, Date, Status, Actions
│   ├── Tap item → JourneyView
│   ├── Long press → Context menu (Edit/Delete)
│   └── Status-based action buttons
├── Floating Action Button → CreateJourneyPlanPage
├── Pull-to-refresh functionality
└── Infinite scroll pagination
```

#### 3.2 Journey Plan Creation Navigation
```
CreateJourneyPlanPage
├── Prerequisites Check:
│   ├── Clock-in status validation
│   └── Show warning if not clocked in
├── Form Sections:
│   ├── Date/Time picker
│   ├── Client search & selection
│   ├── Route selection (dropdown)
│   └── Notes (optional)
├── Client Selection Flow:
│   ├── Search input with debouncing
│   ├── Filtered results with pagination
│   ├── Smart search (name + address)
│   └── Select client → Enable submit
├── Submit → API call → Success/Error handling
└── Navigation:
    ├── Success → Back to JourneyPlansPage
    ├── Cancel → Back to JourneyPlansPage
    └── Error → Stay with error message
```

### 4. Journey Execution Navigation

#### 4.1 Journey View Navigation
```
JourneyView (Individual Journey)
├── Journey Information Display:
│   ├── Client details
│   ├── Date/time
│   ├── Current location
│   ├── Distance to client
│   └── Status indicator
├── Status-Based Actions:
│   ├── Pending → "Check In" button
│   ├── Checked In → "View Reports" button
│   ├── In Progress → "View Reports" button
│   └── Completed → Status display only
├── Check-In Flow:
│   ├── Validate geofence (within range)
│   ├── Tap "Check In" → Camera opens
│   ├── Capture photo → Processing dialog
│   ├── Optimistic UI update
│   └── Navigate to ReportsOrdersPage
└── Additional Actions:
    ├── Update client location
    ├── Add/edit notes
    └── Refresh status
```

#### 4.2 Reports Navigation Flow
```
ReportsOrdersPage (Post Check-in)
├── Journey Information Header
├── Required Reports Section:
│   ├── Product Availability Report
│   │   └── Tap → ProductReportPage
│   ├── Feedback Report
│   │   └── Tap → FeedbackReportPage
│   └── Visibility Report
│       └── Tap → VisibilityReportPage
├── Optional Reports Section:
│   ├── Product Sample Report
│   │   └── Tap → ProductSamplePage
│   └── Product Return Report
│       └── Tap → ProductReturnPage
├── Progress Indicators:
│   ├── Visual checkmarks for completed reports
│   ├── "Ready" badge when all required reports done
│   └── Disabled checkout until requirements met
└── Checkout Section:
    ├── "Complete Visit" button
    ├── Enabled only when all required reports submitted
    └── Tap → Confirmation dialog → Checkout process
```

### 5. Individual Report Navigation

#### 5.1 Product Report Flow
```
ProductReportPage
├── Product Selection:
│   ├── Search products
│   ├── Select from list
│   └── Quantity input
├── Image Capture:
│   ├── Camera button
│   ├── Take photo
│   └── Preview/retake option
├── Form Completion:
│   ├── Comments/notes
│   ├── Availability status
│   └── Quantities
├── Submit → API call → Loading state
└── Navigation:
    ├── Success → Back to ReportsOrdersPage
    ├── Save Draft → Stay on page
    └── Cancel → Back to ReportsOrdersPage
```

#### 5.2 Other Report Flows
```
FeedbackReportPage / VisibilityReportPage / ProductSamplePage / ProductReturnPage
├── Similar structure to ProductReportPage
├── Report-specific form fields
├── Image capture (optional/required)
├── Submit → API call
└── Navigate back to ReportsOrdersPage
```

### 6. Checkout Navigation

#### 6.1 Checkout Process
```
Checkout Confirmation Dialog
├── "Are you sure?" message
├── Cancel → Stay on ReportsOrdersPage
└── Confirm → Execute checkout:
    ├── Get current GPS location
    ├── Update journey status to "Completed"
    ├── Record checkout time & coordinates
    ├── Clear local caches
    ├── Show success message
    └── Navigate back to JourneyPlansPage
```

### 7. Supporting Navigation Flows

#### 7.1 Profile Navigation
```
ProfilePage
├── User Information Display
├── Clock In/Out Controls:
│   ├── Clock In → API call → Update session state
│   ├── Clock Out → Confirmation → API call
│   └── Session history display
├── Targets Section → TargetsPage
├── Settings/Preferences
└── Logout → Confirmation → LoginPage
```

#### 7.2 Client Management Navigation
```
ViewClientPage
├── Client Search & Filter
├── Client List with pagination
├── Tap Client → Client Details
├── Context Actions:
│   ├── Create Order (if forOrderCreation=true)
│   ├── Uplift Sale (if forUpliftSale=true)
│   └── Product Return (if forProductReturn=true)
└── Navigation modes:
    ├── Normal viewing
    ├── Order creation flow
    ├── Uplift sale selection
    └── Product return selection
```

#### 7.3 Order Management Navigation
```
Order Flow:
├── ViewOrdersPage → List all orders
├── AddOrderPage → Create new order
├── Order Details → View/Edit specific order
└── Order Status Management
```

## Navigation Patterns for Repository Pattern

### 1. Screen Structure
```
Each Screen:
├── State Management (GetX/Provider/Bloc)
├── Repository Injection (DI)
├── Use Case Calls
├── UI State Updates
└── Navigation Triggers
```

### 2. Data Flow Pattern
```
User Action → UI Event → Use Case → Repository → Data Source
                ↓
           Navigation Decision
                ↓
        Update UI State → Navigate
```

### 3. Navigation Guards
```
Navigation Middleware:
├── Authentication Check
├── Session Validation
├── Permission Verification
├── Network Status
└── Data Availability
```

## Key Navigation States

### Status-Based Navigation
```
Journey Plan Status Navigation:
├── Pending:
│   ├── Can edit/delete
│   ├── Can check in (if in range)
│   └── Shows distance to client
├── Checked In:
│   ├── Redirect to reports
│   └── Cannot edit/delete
├── In Progress:
│   ├── Access to reports
│   ├── Can checkout (when reports complete)
│   └── Cannot edit/delete
├── Completed:
│   ├── View-only mode
│   ├── Show completion details
│   └── Cannot modify
└── Cancelled:
    ├── View-only mode
    └── Cannot modify
```

### Session-Based Navigation
```
Clock Status Navigation:
├── Not Clocked In:
│   ├── Journey Plans → Blocked (show dialog)
│   ├── Profile → Available (to clock in)
│   └── Other features → Available
└── Clocked In:
    ├── All features → Available
    ├── Journey Plans → Full access
    └── Profile → Show clock out option
```

## Error Navigation Patterns

### Network Error Navigation
```
Network Issues:
├── Show offline indicator
├── Enable offline mode
├── Queue operations for sync
├── Show retry options
└── Graceful degradation
```

### Authentication Error Navigation
```
Auth Issues:
├── Token expired → Auto-refresh
├── Refresh failed → LoginPage
├── Invalid session → LoginPage
└── Permission denied → Error page
```

## Navigation Implementation Notes

### For Repository Pattern:
1. **Inject repositories** into screens via dependency injection
2. **Use cases** handle business logic and navigation decisions
3. **State management** controls UI updates and navigation triggers
4. **Navigation guards** implement access control
5. **Error handling** manages navigation on failures

### Key Navigation Libraries:
- GetX routing (current implementation)
- Navigator 2.0 (for complex routing)
- Auto Route (for type-safe navigation)
- Go Router (for web/deep linking)

### Navigation Best Practices:
1. **Predictable navigation** - Users always know where they are
2. **Breadcrumb navigation** - Clear path back to previous screens
3. **Status-aware navigation** - Actions based on current state
4. **Offline-friendly** - Works without network connection
5. **Performance optimized** - Lazy loading and efficient transitions

This navigation flow is designed to be easily adaptable to the Repository Pattern while maintaining the core user experience and business logic flow of the JourneyPlan system.