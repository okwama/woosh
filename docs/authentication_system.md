# Authentication System Documentation

## Overview

The Woosh authentication system provides secure, progressive login functionality with comprehensive session management, token refresh, and offline capabilities. The system is built with security best practices and supports multiple authentication states.

## 🔐 Authentication Features

### Progressive Login System
- **Multi-step Authentication** - Stepwise login process with validation at each stage
- **Token-based Security** - JWT tokens with automatic refresh capabilities
- **Offline Authentication** - Cached credentials for offline access
- **Session Persistence** - Secure local storage of authentication state

### Security Features
- **Password Encryption** - Secure password hashing and storage
- **Token Refresh** - Automatic token renewal to maintain sessions
- **Session Timeout** - Configurable session expiration
- **Account Lockout** - Protection against brute force attacks
- **Device Registration** - Trusted device management

## 🚀 User Flows

### 1. User Registration (Sign Up)

#### Flow Overview
```
Start → Enter Details → Validation → Account Creation → Welcome → Home Dashboard
```

#### Step-by-Step Process

**Step 1: Initial Registration**
- User selects "Sign Up" from login screen
- Form fields include:
  - Full Name (required)
  - Email Address (required, validated)
  - Phone Number (required)
  - Password (required, strength validation)
  - Confirm Password (required, must match)
  - Employee ID (optional)
  - Department (dropdown selection)

**Step 2: Validation**
- Real-time email format validation
- Password strength requirements:
  - Minimum 8 characters
  - At least one uppercase letter
  - At least one lowercase letter
  - At least one number
  - At least one special character
- Phone number format validation
- Employee ID verification (if provided)

**Step 3: Account Creation**
- API call to create user account
- Email verification sent (if required)
- Account activation process
- Initial profile setup

**Step 4: Welcome Flow**
- Registration success confirmation
- Initial app tour (optional)
- Permission requests (location, camera, etc.)
- Default settings configuration

### 2. User Login

#### Flow Overview
```
Start → Credentials → Validation → Token Generation → Session Setup → Dashboard
```

#### Step-by-Step Process

**Step 1: Login Form**
- Username/Email field (required)
- Password field (required)
- "Remember Me" option
- "Forgot Password" link
- Biometric login option (if enabled)

**Step 2: Progressive Authentication**
- Initial credential validation
- Multi-factor authentication (if enabled)
- Device verification
- Session token generation

**Step 3: Session Establishment**
- JWT token storage
- Refresh token setup
- User preferences loading
- Permission verification

**Step 4: Dashboard Access**
- Home screen navigation
- Initial data synchronization
- Background services initialization

### 3. Session Management

#### Active Session Monitoring
- **Heartbeat Checks** - Regular session validation
- **Activity Tracking** - User interaction monitoring
- **Automatic Refresh** - Token renewal before expiration
- **Graceful Logout** - Clean session termination

#### Session Persistence
- **Local Storage** - Secure credential caching
- **Cross-Device Sync** - Session state synchronization
- **Offline Continuity** - Maintained sessions without connectivity
- **Recovery Mechanisms** - Session restoration after app restart

### 4. Password Management

#### Password Reset Flow
```
Forgot Password → Email/Phone Verification → Reset Code → New Password → Confirmation
```

**Step 1: Reset Request**
- User clicks "Forgot Password"
- Email or phone number entry
- Security question (if configured)

**Step 2: Verification**
- Reset code sent via email/SMS
- Code entry and validation
- Time-limited validity (15 minutes)

**Step 3: Password Update**
- New password entry
- Confirmation field
- Strength validation
- Security requirements met

**Step 4: Completion**
- Password update confirmation
- Automatic login option
- Security notification sent

#### Password Change (Authenticated)
```
Current Password → New Password → Confirmation → Update → Success
```

### 5. Account Security

#### Security Settings
- **Two-Factor Authentication** - SMS/Email based 2FA
- **Biometric Authentication** - Fingerprint/Face ID
- **Device Management** - Trusted device list
- **Session History** - Login activity tracking
- **Security Notifications** - Suspicious activity alerts

#### Account Deletion
```
Security Verification → Confirmation → Data Export → Account Removal → Confirmation
```

**Step 1: Security Check**
- Password re-entry required
- 2FA verification (if enabled)
- Identity confirmation

**Step 2: Data Handling**
- Data export option
- Deletion confirmation
- Legal compliance notices

**Step 3: Account Removal**
- Complete data deletion
- Session termination
- Notification confirmation

## 🛠️ Technical Implementation

### Authentication Controllers

#### AuthController (`lib/controllers/auth_controller.dart`)
```dart
class AuthController extends GetxController {
  // Core authentication methods
  Future<bool> login(String email, String password)
  Future<bool> register(UserRegistration registration)
  Future<void> logout()
  Future<bool> refreshToken()
  
  // Session management
  bool get isAuthenticated
  User? get currentUser
  String? get authToken
}
```

### Services Integration

#### Progressive Login Service (`lib/services/progressive_login_service.dart`)
- **Multi-step Authentication** - Handles complex login flows
- **Token Management** - JWT token handling and refresh
- **Offline Support** - Cached authentication for offline use
- **Security Validation** - Multi-layer security checks

#### Token Service (`lib/services/token_service.dart`)
- **Token Storage** - Secure local token management
- **Refresh Logic** - Automatic token renewal
- **Expiration Handling** - Token lifecycle management
- **Security Monitoring** - Token integrity validation

### Data Models

#### User Model (`lib/models/user_model.dart`)
```dart
class User {
  String id;
  String name;
  String email;
  String phone;
  String? employeeId;
  String department;
  DateTime createdAt;
  DateTime lastLoginAt;
  bool isActive;
  UserRole role;
}
```

#### Session Model (`lib/models/session_model.dart`)
```dart
class Session {
  String sessionId;
  String userId;
  String accessToken;
  String refreshToken;
  DateTime expiresAt;
  DateTime createdAt;
  String deviceInfo;
  bool isActive;
}
```

### Security Implementation

#### Secure Storage
- **Hive Encryption** - Local database encryption
- **Token Encryption** - JWT token secure storage
- **Keychain Integration** - Platform-specific secure storage
- **Biometric Protection** - Hardware security integration

#### Network Security
- **HTTPS Only** - Encrypted API communication
- **Certificate Pinning** - Man-in-the-middle protection
- **Request Signing** - API request integrity
- **Rate Limiting** - Brute force protection

## 📱 User Interface Components

### Login Screen (`lib/pages/login/login_page.dart`)
- **Responsive Design** - Adapts to different screen sizes
- **Brand Consistency** - Woosh brand colors and typography
- **Accessibility** - Screen reader and keyboard navigation support
- **Error Handling** - Clear error messages and recovery options

### Registration Screen (`lib/pages/login/sign_page.dart`)
- **Form Validation** - Real-time input validation
- **Progress Indicators** - Visual feedback during registration
- **Help Text** - Contextual assistance for form fields
- **Success Feedback** - Registration completion confirmation

### Profile Management (`lib/pages/profile/profile.dart`)
- **Account Settings** - Comprehensive profile management
- **Security Options** - Password change and 2FA setup
- **Session History** - Login activity and device management
- **Account Actions** - Logout and account deletion options

## 🔧 Configuration

### Authentication Settings
```yaml
# config/auth_config.yaml
authentication:
  session_timeout: 3600  # 1 hour
  token_refresh_threshold: 300  # 5 minutes before expiry
  max_login_attempts: 5
  lockout_duration: 1800  # 30 minutes
  password_requirements:
    min_length: 8
    require_uppercase: true
    require_lowercase: true
    require_numbers: true
    require_special_chars: true
```

### API Endpoints
```dart
// Authentication endpoints
const String LOGIN_ENDPOINT = '/api/auth/login';
const String REGISTER_ENDPOINT = '/api/auth/register';
const String REFRESH_ENDPOINT = '/api/auth/refresh';
const String LOGOUT_ENDPOINT = '/api/auth/logout';
const String RESET_PASSWORD_ENDPOINT = '/api/auth/reset-password';
```

## 🚨 Error Handling

### Common Error Scenarios
1. **Invalid Credentials** - Clear error message with retry option
2. **Network Connectivity** - Offline mode activation
3. **Session Expired** - Automatic refresh or re-login prompt
4. **Account Locked** - Lockout notification with recovery options
5. **Server Errors** - Graceful degradation with retry mechanisms

### Error Recovery
- **Automatic Retry** - Network request retry with exponential backoff
- **Offline Fallback** - Cached credential validation
- **User Guidance** - Clear instructions for error resolution
- **Support Integration** - Easy access to help and support

## 📊 Analytics & Monitoring

### Authentication Metrics
- **Login Success Rate** - Authentication success tracking
- **Session Duration** - Average session length monitoring
- **Error Frequency** - Authentication error analysis
- **Security Events** - Suspicious activity detection

### User Behavior
- **Login Patterns** - Time-based login analysis
- **Feature Usage** - Post-authentication feature adoption
- **Session Activity** - User engagement during sessions
- **Retention Metrics** - User return rate analysis

## 🔄 Offline Functionality

### Offline Authentication
- **Cached Credentials** - Secure local credential storage
- **Biometric Fallback** - Hardware-based authentication
- **Session Persistence** - Maintained authentication state
- **Sync on Reconnect** - Automatic session validation when online

### Data Synchronization
- **Authentication State** - Session status synchronization
- **User Profile** - Profile data updates when connected
- **Security Events** - Offline security event queuing
- **Conflict Resolution** - Handling concurrent authentication changes

## 🔒 Security Best Practices

### Implementation Guidelines
1. **Never store plain text passwords**
2. **Use secure token storage mechanisms**
3. **Implement proper session timeout**
4. **Monitor for suspicious activities**
5. **Regular security audits and updates**

### Compliance Considerations
- **Data Privacy** - GDPR and CCPA compliance
- **Password Policies** - Industry standard requirements
- **Audit Logging** - Comprehensive security event logging
- **Regulatory Compliance** - Industry-specific security standards

## 📞 Troubleshooting

### Common Issues
1. **Cannot Login** - Check credentials, network, and server status
2. **Session Expires Quickly** - Verify token refresh settings
3. **Forgot Password Not Working** - Check email/SMS delivery
4. **Biometric Login Fails** - Hardware and permission verification
5. **Account Locked** - Contact admin or wait for lockout expiry

### Support Resources
- **User Guide** - Step-by-step authentication help
- **FAQ Section** - Common authentication questions
- **Contact Support** - Direct support for authentication issues
- **System Status** - Real-time authentication service status

---

**Last Updated**: December 2024  
**Version**: 1.0.7+1  
**Applies to**: All platforms (Android, iOS, Web, Desktop) 