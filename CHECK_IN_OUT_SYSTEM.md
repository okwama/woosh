# Check-in/Check-out System Documentation

## Overview
The Whoosh application implements a comprehensive check-in/check-out system for guards and supervisors to track visits to premises. The system captures location data, timestamps, and optional photos to verify presence at designated locations.

## Journey Plan Status Flow
1. **Pending (0)** - Initial state when a journey plan is created
2. **Checked In (1)** - Guard has checked in at the location
3. **In Progress (2)** - Visit is ongoing after check-in
4. **Completed (3)** - Visit is completed after check-out
5. **Cancelled (4)** - Journey plan was cancelled

## Components

### Data Model
**File**: `lib/models/journeyplan_model.dart`

Key properties:
- `checkInTime`: DateTime when check-in occurred
- `latitude` and `longitude`: GPS coordinates at check-in
- `imageUrl`: Optional photo taken during check-in
- `checkoutTime`: DateTime when check-out occurred
- `checkoutLatitude` and `checkoutLongitude`: GPS coordinates at check-out

### Check-in Process
**File**: `lib/pages/journeyplan/journeyview.dart`

Functionality:
1. **Geofence Validation**
   - Verifies the guard is within the required radius of the destination
   - Uses Haversine formula to calculate distance between coordinates
   - Configurable geofence radius (default appears to be in meters)

2. **Check-in Workflow**
   - User confirms check-in via dialog
   - Captures current GPS coordinates
   - Optionally takes a photo for verification
   - Updates journey plan status to "Checked In" (1)
   - Records timestamp and location data
   - Updates UI to reflect checked-in state

3. **Post Check-in State**
   - Changes available actions based on check-in status
   - Transitions to "In Progress" (2) state for active visits
   - Displays check-in information including time and location

### Check-out Process
**Files**: 
- `lib/pages/journeyplan/reports/reportMain_page.dart`
- `lib/pages/journeyplan/reports/base_report_page.dart`

Functionality:
1. **Check-out Workflow**
   - User confirms check-out via dialog
   - Captures final GPS coordinates
   - Updates journey plan status to "Completed" (3)
   - Records checkout timestamp
   - Sends data to API for persistence

2. **Checkout API Integration**
   - Logs checkout process with detailed debugging
   - Updates the journey plan data using the API service
   - Validates API response for successful checkout
   - Provides error handling and user feedback

### API Service
**File**: `lib/services/api_service.dart`

Key methods:
- `updateJourneyPlan()`: Handles both check-in and check-out operations
  - Updates status, coordinates, timestamps, and media for a journey plan
  - Handles error scenarios and network issues
  - Provides detailed logging, especially for checkout operations

## Validation and Error Handling

1. **Location Validation**
   - Guards must be physically present at the designated location
   - System validates proximity using geofencing
   - Error messages displayed if user is out of range

2. **Network and API Error Handling**
   - Graceful handling of network connectivity issues
   - Detailed error reporting in API communication
   - User feedback for failed check-in/check-out attempts

3. **State Transition Validation**
   - System enforces correct state transitions
   - Contains logic to fix incorrect states (e.g., stuck in "Checked In" instead of "In Progress")

## User Interface

1. **Check-in Button**
   - Displayed when journey plan is in "Pending" state
   - Disabled when outside geofence boundaries
   - Shows loading state during check-in process

2. **Check-out Button**
   - Available after successful check-in
   - Typically located in report pages after visit completion
   - Confirms user intent via dialog before processing

3. **Status Indicators**
   - Color-coded status indicators
   - Different actions available based on current status
   - Map view showing check-in location when available

## Debugging Features

The system includes comprehensive logging, especially for the checkout process:
- Location coordinates
- Accuracy of GPS readings
- Timestamps for each operation
- API request and response details
- Error conditions and exception handling 