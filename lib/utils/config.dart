class Config {
  static const String baseUrl = 'http://147.182.202.116:3000';  // API prefix is added in routes
  static const String apiVersion = 'v1';
  static const String imageBaseUrl = 'http://147.182.202.116:3000/uploads';  // For uploaded files
  // ImageKit configuration
  
  // API Endpoints - all prefixed with /api in ApiService
  static const String authEndpoint = '/api/auth';
  static const String loginEndpoint = '/api/auth/login';
  static const String productsEndpoint = '/api/products';
  static const String ordersEndpoint = '/api/orders';
  static const String outletsEndpoint = '/api/outlets';
  static const String journeyPlansEndpoint = '/api/journey-plans';
  static const String noticeBoardEndpoint = '/api/notice-board';
  static const String reportsEndpoint = '/api/reports';
  static const String leaveEndpoint = '/api/leave';
  static const String profileEndpoint = '/api/profile';
  static const String uploadEndpoint = '/api/upload-image';
  
  // Cache Configuration
  static const Duration defaultCacheValidity = Duration(minutes: 5);
  static const Duration imageCacheValidity = Duration(hours: 1);
  
  // Image Configuration
  static const int maxImageWidth = 800;  // For product images
  static const int maxImageHeight = 800;  // For product images
  static const double imageThumbnailQuality = 0.8;
}
