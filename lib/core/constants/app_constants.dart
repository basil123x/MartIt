class AppConstants {
  // App Info
  static const String appName = 'Globee';
  static const String appVersion = '1.0.0';

  /// Albadaa store on Globee / martit S3 (store_4).
  static const String albadaaStoreId = '5';
  
  // API Configuration
  static const String baseUrl = 'https://your-api-domain.com/api/';
  static const String apiVersion = 'v1';
  
  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String cartItemsKey = 'cart_items';
  static const String favoritesKey = 'favorites';
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxVideoLength = 60; // seconds
  
  // File Upload
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB
  
  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
}
