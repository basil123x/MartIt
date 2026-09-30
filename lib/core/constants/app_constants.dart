import 'dart:math' as math;

class AppConstants {
  // App Info
  static const String appName = 'MartIt';
  static const String appVersion = '1.0.0';

  /// Prefer [ApiConfigService.instance.apiBaseUrl] at runtime.
  /// Kept only as a compile-time fallback placeholder.
  static const String baseUrl = 'https://www.mart-it.store/app2026';
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

  /// Per-flavor store id (`--dart-define=STORE_ID=2`). Empty = no store filter.
  static const String storeId = String.fromEnvironment(
    'STORE_ID',
    defaultValue: '',
  );

  /// OpenStreetMap raster tile URL for [lat]/[lng] at [zoom]. No API key.
  static String osmTileUrl({
    required double lat,
    required double lng,
    int zoom = 16,
  }) {
    final x = _lonToTileX(lng, zoom);
    final y = _latToTileY(lat, zoom);
    return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
  }

  /// OSM static map preview with a red pushpin (no API key).
  static String osmStaticMapUrl({
    required double lat,
    required double lng,
    int width = 300,
    int height = 180,
    int zoom = 16,
  }) {
    return 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$lat,$lng'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&maptype=mapnik'
        '&markers=$lat,$lng,red-pushpin';
  }

  /// Google Maps deep-link for opening a location externally.
  static String googleMapsSearchUrl({
    required double lat,
    required double lng,
  }) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  /// OpenStreetMap page centered on the location with a marker.
  static String osmLocationPageUrl({
    required double lat,
    required double lng,
    int zoom = 17,
  }) {
    return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=$zoom/$lat/$lng';
  }

  static int _lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  static int _latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    final n = 1 << zoom;
    return ((1.0 -
                (math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) /
                    math.pi)) /
            2.0 *
            n)
        .floor()
        .clamp(0, n - 1);
  }
}
