# JourneyPlan Individual Reports Explained

## Overview
After checking into a client location, sales representatives must complete various reports to document their visit activities. These reports capture different aspects of the client interaction and product management.

## Report Categories

### Required Reports (Must Complete Before Checkout)
1. **Product Availability Report**
2. **Feedback Report** 
3. **Visibility Report**

### Optional Reports
4. **Product Sample Report**
5. **Product Return Report**

---

## 1. Product Availability Report

### Purpose
Track product availability, stock levels, and quantities at the client location.

### Navigation Flow
```
ReportsOrdersPage → ProductReportPage
├── Product Selection (searchable list with pagination)
├── Quantity Input (per product)
├── Comments/Notes
├── Offline Support (Hive storage)
└── Submit → Back to ReportsOrdersPage
```

### Key Features
- **Multi-Product Support**: Can report on multiple products in one session
- **Smart Search**: Search products by name with debouncing
- **Quantity Tracking**: Record available quantities for each product
- **Pagination**: Load products in batches (20 per page)
- **Offline Storage**: Uses ProductReportHiveService for offline capability
- **Auto-sync**: Syncs unsubmitted reports when online

### Data Structure
```dart
ProductReport {
  reportId: int
  productName: String?
  productId: int?
  quantity: int?
  comment: String?
  createdAt: DateTime
}
```

### UI Components
- Product search bar with real-time filtering
- Product list with selection checkboxes
- Quantity input fields for each selected product
- Comments section for additional notes
- Progress indicators for submission status

---

## 2. Feedback Report

### Purpose
Capture client feedback, complaints, suggestions, or general comments about products/services.

### Navigation Flow
```
ReportsOrdersPage → FeedbackReportPage
├── Feedback Text Input (required)
├── Character limit validation
├── Optimistic submission (immediate navigation back)
└── Background sync with error handling
```

### Key Features
- **Simple Text Input**: Large text field for feedback
- **Optimistic UI**: Immediately shows success and navigates back
- **Background Sync**: Actual API submission happens in background
- **Error Recovery**: Shows retry options if sync fails
- **Network Awareness**: Different messages for offline vs online errors

### Data Structure
```dart
FeedbackReport {
  reportId: int
  comment: String
}
```

### UI Components
- Large text input field
- Character counter
- Submit button with loading state
- Error handling with retry options

---

## 3. Visibility Report

### Purpose
Document brand visibility, product placement, promotional materials, and store appearance with photographic evidence.

### Navigation Flow
```
ReportsOrdersPage → VisibilityReportPage
├── Photo Capture (required - camera only)
├── Image Compression & Optimization
├── Comments/Notes Input
├── GPS Location Capture
├── Upload Progress Tracking
└── Submit → Back to ReportsOrdersPage
```

### Key Features
- **Mandatory Photo**: Must capture image using camera (no gallery selection)
- **Image Optimization**: 
  - Automatic compression to reduce file size
  - Resize to max 800x800 pixels
  - Progressive JPEG compression (85% → 60% quality if needed)
  - Target size: ~100KB
- **Upload Progress**: Real-time progress indicator during image upload
- **Location Tagging**: Captures GPS coordinates with the report
- **Quality Controls**: Maintains image quality while optimizing size

### Data Structure
```dart
VisibilityReport {
  reportId: int
  imageUrl: String?
  comment: String?
  latitude: double?
  longitude: double?
}
```

### UI Components
- Camera capture button
- Image preview with compression info
- Upload progress bar
- Comments text field
- Location status indicator

---

## 4. Product Sample Report (Optional)

### Purpose
Track product samples given to clients for testing or promotional purposes.

### Navigation Flow
```
ReportsOrdersPage → ProductSamplePage
├── Product Selection (dropdown/search)
├── Quantity Input
├── Reason/Purpose Input
├── Cart System (multiple products)
├── Review Cart Items
└── Submit All → Back to ReportsOrdersPage
```

### Key Features
- **Cart System**: Add multiple products with different quantities and reasons
- **Product Search**: Select from available product catalog
- **Reason Tracking**: Mandatory reason for each sample given
- **Batch Submission**: Submit all cart items as one report
- **Validation**: Ensures all required fields are filled

### Data Structure
```dart
ProductSample {
  items: List<ProductSampleItem>
}

ProductSampleItem {
  productId: int
  quantity: int
  reason: String
}
```

### UI Components
- Product selection dropdown
- Quantity input field
- Reason text input
- Cart display with item management
- Add to cart button
- Submit cart button

---

## 5. Product Return Report (Optional)

### Purpose
Document products returned by clients due to defects, expiration, or other issues.

### Navigation Flow
```
ReportsOrdersPage → ProductReturnPage
├── Product Selection
├── Return Quantity Input
├── Return Reason (required)
├── Optional Photo Evidence
├── Cart System (multiple returns)
└── Submit → Back to ReportsOrdersPage
```

### Key Features
- **Return Tracking**: Document products being returned
- **Reason Codes**: Mandatory reason for each return
- **Photo Evidence**: Optional camera capture for return documentation
- **Multiple Items**: Cart system for bulk returns
- **Quantity Validation**: Ensures valid return quantities

### Data Structure
```dart
ProductReturn {
  items: List<ProductReturnItem>
  imageUrl: String? // Optional photo evidence
}

ProductReturnItem {
  productId: int
  quantity: int
  reason: String
}
```

### UI Components
- Product selection interface
- Return quantity inputs
- Reason selection/input
- Optional camera capture
- Cart management system

---

## Report Submission Flow

### Common Submission Pattern
```
Individual Report Page
├── Form Validation
├── Data Collection
├── Optimistic UI Update (where applicable)
├── API Submission
├── Error Handling
└── Navigate Back to ReportsOrdersPage
```

### Progress Tracking
```
ReportsOrdersPage
├── Visual Indicators:
│   ├── ✅ Completed reports (green checkmark)
│   ├── 📝 Required reports (highlighted)
│   └── 🔒 Checkout locked until required reports done
├── Progress Summary:
│   ├── "X of Y required reports completed"
│   └── "Ready to checkout" when all required done
```

## Technical Implementation Notes

### Offline Capability
- **Product Reports**: Full offline support with Hive storage
- **Other Reports**: Optimistic UI with background sync
- **Image Uploads**: Queued for upload when connection restored
- **Sync Status**: Visual indicators for pending uploads

### Data Validation
- **Required Fields**: Enforced at UI level
- **Image Compression**: Automatic optimization for network efficiency
- **GPS Validation**: Location services integration
- **Form State**: Real-time validation feedback

### Error Handling
- **Network Errors**: Graceful degradation with offline storage
- **Validation Errors**: Immediate user feedback
- **Upload Failures**: Retry mechanisms with user control
- **Session Errors**: Token refresh and re-authentication

### Performance Optimizations
- **Image Compression**: Reduces upload time and bandwidth
- **Pagination**: Efficient loading of large product lists
- **Caching**: SharedDataService for product data
- **Debounced Search**: Optimized search performance

## Repository Pattern Integration

### For Each Report Type:
```
UI Layer (Report Pages)
├── Report Use Cases
├── Report Repository Interface
└── Data Sources:
    ├── Remote API
    ├── Local Hive Storage
    └── Camera/GPS Services
```

### Key Repository Methods:
- `submitProductReport(ProductReport report)`
- `submitFeedbackReport(FeedbackReport report)`
- `submitVisibilityReport(VisibilityReport report)`
- `uploadReportImage(File imageFile)`
- `getUnsyncedReports()`
- `syncPendingReports()`

This structure ensures clean separation of concerns while maintaining the comprehensive reporting functionality required for field sales operations.