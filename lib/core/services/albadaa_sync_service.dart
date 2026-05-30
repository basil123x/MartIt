import 'dart:convert';

import 'package:dio/dio.dart';

class AlbadaaSyncService {
  static const String _syncUrl =
      'https://bluemarinelife.com/sys2024/sync_receive.php?k=42654868';
  static const String _syncKey = 'BML_Secret_2026';

  static const _syncHeaders = {
    'X-Sync-Key': _syncKey,
    'Content-Type': 'application/json',
  };

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  static Map<String, dynamic>? _parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  /// Albadaa insert_empty — only used via Globee insertNewOne → syncEmptyToClient('4').
  /// Do not call from the app (duplicates rows with insertNewOne).
  static Future<Map<String, dynamic>?> insertEmpty() async {
    try {
      final response = await _dio.post(
        _syncUrl,
        data: jsonEncode({'action': 'insert_empty'}),
        options: Options(
          headers: _syncHeaders,
          contentType: 'application/json',
        ),
      );
      final body = _parseResponse(response.data);
      if (body?['success'] == true) {
        print('🏪 Albadaa insert_empty → id: ${body!['id']}');
      } else {
        print('🏪 Albadaa insert_empty → failed: $body');
      }
      return body;
    } catch (e) {
      print('🏪 Albadaa insert_empty → error: $e');
      return null;
    }
  }

  /// Call 2 — sync item fields after images are uploaded.
  static Future<Map<String, dynamic>?> syncItemData({
    required int id,
    required String barcode,
    required String englishName,
    required String arabicName,
    required String category,
    required String price,
    required String quantity,
  }) async {
    try {
      final payload = {
        'id': id,
        'a1': barcode,
        'a3': englishName,
        'a4': arabicName,
        'a5': category,
        'a10': price,
        'a33': int.tryParse(quantity) ?? 0,
      };
      final response = await _dio.post(
        _syncUrl,
        data: jsonEncode(payload),
        options: Options(headers: _syncHeaders),
      );
      final body = _parseResponse(response.data);
      print('🏪 Albadaa sync data → $body');
      return body;
    } catch (e) {
      print('🏪 Albadaa sync data → error: $e');
      return null;
    }
  }
}
