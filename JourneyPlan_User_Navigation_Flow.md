# JourneyPlan User Navigation Flow

## Overview
This document outlines the user navigation flow specifically for the **JourneyPlan feature**, designed for implementation with the Repository Pattern. It focuses on the complete journey planning and execution workflow.

## JourneyPlan Navigation Architecture

### Repository Pattern Integration
```
JourneyPlan UI → JourneyPlan Use Cases → JourneyPlan Repository → Data Sources (API/Local)
```

## JourneyPlan User Navigation Flow

### 1. Entry Points to JourneyPlan

#### 1.1 From Dashboard
```
HomePage
├── Journey Plans Menu Tile (with badge count)
├── Session Validation Check
│   ├── If Not Clocked In → Session Required Dialog
│   └── If Clocked In → JourneyPlansLoadingScreen
```

#### 1.2 Session Validation Flow
```
Session Check:
├── Clock Status Validation
├── If Session Inactive:
│   ├── Show "Session Required" Dialog
│   ├── Options:
│   │   ├── Cancel → Stay on HomePage
│   │   └── Start Session → Navigate to ProfilePage
│   └── After Clock-In → Auto-navigate to JourneyPlans
└── If Session Active → Direct access to JourneyPlans
```

### 2. JourneyPlan List Management

#### 2.1 Loading Screen Navigation
```
JourneyPlansLoadingScreen
├── Show "Loading Journey Plans..." indicator
├── Preload Data:
│   ├── Fetch journey plans from repository
│   ├── Fetch clients from repository
│   └── Handle loading errors gracefully
└── Navigate to JourneyPlansPage (with preloaded data)
```

#### 2.2 Journey Plans List Navigation
```
JourneyPlansPage
├── App Bar:
│   ├── Title: "Journey Plans"
│   ├── Sort button (ascending/descending)
│   └── Refresh button
├── Filter Controls:
│   ├── Status filter dropdown (All/Pending/In Progress/Completed)
│   ├── Date picker filter
│   └── Search bar (debounced)
├── Active Visit Banner:
│   ├── Shows current in-progress journey
│   ├── Tap → Navigate to JourneyView
│   └── Visible only when active visit exists
├── Journey Plans List:
│   ├── Card-based layout
│   ├── Each card shows:
│   │   ├── Client name and address
│   │   ├── Date and time
│   │   ├── Status badge with color
│   │   └── Action buttons (status-dependent)
│   ├── Card Actions:
│   │   ├── Tap → Navigate to JourneyView
│   │   ├── Long press → Context menu
│   │   └── Status-specific buttons
├── List Interactions:
│   ├── Pull-to-refresh → Reload from repository
│   ├── Infinite scroll → Load more pages
│   └── Empty state → "No journey plans" message
├── Floating Action Button:
│   ├── "+" button → Navigate to CreateJourneyPlanPage
│   └── Only visible when session is active
└── Navigation Options:
    ├── Back → HomePage
    ├── Create → CreateJourneyPlanPage
    └── View Journey → JourneyView
```

### 3. Journey Plan Creation Flow

#### 3.1 Create Journey Navigation
```
CreateJourneyPlanPage
├── App Bar:
│   ├── Title: "Create Journey Plan"
│   ├── Back button → JourneyPlansPage
│   └── Save button (enabled when form valid)
├── Prerequisites Validation:
│   ├── Check clock-in status
│   ├── If not clocked in:
│   │   ├── Show warning banner
│   │   ├── Disable form submission
│   │   └── Option to go back and clock in
├── Form Navigation:
│   ├── Date/Time Selection:
│   │   ├── Date picker → Calendar dialog
│   │   └── Time picker → Time dialog
│   ├── Client Selection:
│   │   ├── Search input (with debouncing)
│   │   ├── Filtered client list
│   │   ├── Pagination (20 per page)
│   │   ├── Tap client → Select and highlight
│   │   └── Smart search (name + address matching)
│   ├── Route Selection:
│   │   ├── Dropdown with available routes
│   │   └── Auto-select if user has default route
│   └── Notes Section:
│       ├── Optional text input
│       └── Character limit indicator
├── Form Validation:
│   ├── Required fields: Date, Client
│   ├── Real-time validation feedback
│   └── Submit button state management
├── Submission Flow:
│   ├── Tap Save → Loading indicator
│   ├── Repository call → Create journey plan
│   ├── Success → Navigate back to JourneyPlansPage
│   ├── Error → Show error dialog, stay on page
│   └── Offline → Save locally, show offline indicator
└── Exit Options:
    ├── Back button → Confirm unsaved changes
    ├── Save → Submit and navigate back
    └── Cancel → Discard and navigate back
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