import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remote API domain config.
///
/// Bootstrap URL stays fixed on the control-plane host. The JSON there can
/// point the app at any API base without shipping a store update.
///
/// Deploy this file at: https://www.mart-it.store/app_config.json
/// ```json
/// {
///   "api_base_url": "https://www.mart-it.store/app2026",
///   "latest_version": "1.2.2",
///   "force_update": true,
///   "play_store_url": "https://play.google.com/store/apps/details?id=com.mazo.market",
///   "app_store_url": "https://apps.apple.com/app/idXXXXXXXX",
///   "huawei_store_url": "https://appgallery.huawei.com/app/CXXXXXXXX"
/// }
/// ```
class ApiConfigService {
  ApiConfigService._();
  static final ApiConfigService instance = ApiConfigService._();

  /// Fixed control-plane URL (only this should stay hardcoded in the app).
  static const String bootstrapConfigUrl =
      'https://www.mart-it.store/app_config.json';

  static const String _defaultApiBaseUrl =
      'https://www.mart-it.store/app2026';

  static const String _prefsKey = 'martit_api_base_url';
  static const String _configPrefsKey = 'martit_app_config_json';

  static const String _defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mazo.market';

  String _apiBaseUrl = _defaultApiBaseUrl;
  String _latestVersion = '';
  bool _forceUpdate = true;
  String _updateMessageAr = '';
  String _updateMessageEn = '';
  String _playStoreUrl = _defaultPlayStoreUrl;
  String _appStoreUrl = '';
  String _huaweiStoreUrl = '';
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Active API root, e.g. `https://www.mart-it.store/app2026`
  String get apiBaseUrl => _apiBaseUrl;

  /// Unified store version. The app blocks when the installed version is older.
  String get latestVersion => _latestVersion;

  bool get forceUpdate => _forceUpdate;

  String get playStoreUrl => _playStoreUrl;

  String get appStoreUrl => _appStoreUrl;

  String get huaweiStoreUrl => _huaweiStoreUrl;

  String updateMessageFor({required bool isArabic}) {
    final message = isArabic ? _updateMessageAr : _updateMessageEn;
    return message.trim();
  }

  String get sqlEndpoint => '$apiBaseUrl/sql.php';

  String sqlUrl() =>
      '$sqlEndpoint?k=${DateTime.now().millisecondsSinceEpoch}';

  String endpoint(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$apiBaseUrl/$clean';
  }

  /// Load cached value first, then refresh from remote JSON.
  Future<void> init({bool refreshRemote = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedConfig = prefs.getString(_configPrefsKey);
    if (cachedConfig != null && cachedConfig.trim().isNotEmpty) {
      _applyDecoded(cachedConfig);
    } else {
      final cached = prefs.getString(_prefsKey);
      if (cached != null && cached.trim().isNotEmpty) {
        _apiBaseUrl = _normalizeBaseUrl(cached);
      }
    }
    _initialized = true;

    if (refreshRemote) {
      await refreshFromRemote();
    }
  }

  /// Fetch latest config from [bootstrapConfigUrl] and cache it.
  Future<bool> refreshFromRemote() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          responseType: ResponseType.plain,
          headers: {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ),
      );

      final response = await dio.get(
        '$bootstrapConfigUrl?k=${DateTime.now().millisecondsSinceEpoch}',
      );

      if (response.statusCode != 200 || response.data == null) {
        return false;
      }

      final raw = response.data.toString();
      final decoded = json.decode(raw);
      if (decoded is! Map) return false;

      _applyMap(Map<String, dynamic>.from(decoded));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configPrefsKey, json.encode(decoded));
      await prefs.setString(_prefsKey, _apiBaseUrl);
      _initialized = true;
      print('ApiConfig: api_base_url => $_apiBaseUrl');
      print('ApiConfig: latest_version => $_latestVersion');
      return true;
    } catch (e) {
      print('ApiConfig refresh failed: $e');
      return false;
    }
  }

  void _applyDecoded(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        _applyMap(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      print('ApiConfig cache parse failed: $e');
    }
  }

  void _applyMap(Map<String, dynamic> decoded) {
    final next = decoded['api_base_url']?.toString().trim() ?? '';
    if (next.isNotEmpty) {
      _apiBaseUrl = _normalizeBaseUrl(next);
    }
    if (decoded.containsKey('latest_version')) {
      _latestVersion = decoded['latest_version']?.toString().trim() ?? '';
    }
    if (decoded.containsKey('force_update')) {
      final force = decoded['force_update'];
      final text = force?.toString().toLowerCase();
      _forceUpdate = force == true ||
          force == 1 ||
          text == '1' ||
          text == 'true';
    }
    if (decoded.containsKey('update_message_ar')) {
      _updateMessageAr = decoded['update_message_ar']?.toString() ?? '';
    }
    if (decoded.containsKey('update_message_en')) {
      _updateMessageEn = decoded['update_message_en']?.toString() ?? '';
    }
    if (decoded.containsKey('play_store_url')) {
      _playStoreUrl = _cleanUrl(
        decoded['play_store_url']?.toString() ?? '',
        fallback: _defaultPlayStoreUrl,
      );
    }
    if (decoded.containsKey('app_store_url')) {
      _appStoreUrl = _cleanUrl(decoded['app_store_url']?.toString() ?? '');
    }
    if (decoded.containsKey('huawei_store_url')) {
      _huaweiStoreUrl = _cleanUrl(decoded['huawei_store_url']?.toString() ?? '');
    }
  }

  String _cleanUrl(String url, {String fallback = ''}) {
    final value = url.trim();
    return value.isEmpty ? fallback : value;
  }

  String _normalizeBaseUrl(String url) {
    var value = url.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
