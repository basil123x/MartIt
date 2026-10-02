import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'api_config_service.dart';

class _BlockedSeller {
  _BlockedSeller(this.ids, this.name);

  final Set<String> ids;
  final String name;
}

/// Sellers the signed-in user has blocked. Feed and search listen and hide
/// their products immediately.
class BlockedSellers extends ChangeNotifier {
  BlockedSellers._();
  static final BlockedSellers instance = BlockedSellers._();

  final List<_BlockedSeller> _groups = <_BlockedSeller>[];
  Future<void>? _syncing;

  bool containsSeller(String id, String uid, [String name = '']) {
    final normalized = name.trim().toLowerCase();
    for (final group in _groups) {
      if (id.isNotEmpty && group.ids.contains(id)) return true;
      if (uid.isNotEmpty && group.ids.contains(uid)) return true;
      if (normalized.isNotEmpty && group.name == normalized) return true;
    }
    return false;
  }

  void block(Iterable<String> ids, {String name = ''}) {
    final incoming = ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    final normalized = name.trim().toLowerCase();
    if (incoming.isEmpty && normalized.isEmpty) return;

    final merged = <String>{...incoming};
    var mergedName = normalized;
    _groups.removeWhere((group) {
      final overlaps = group.ids.intersection(incoming).isNotEmpty ||
          (normalized.isNotEmpty && group.name == normalized);
      if (!overlaps) return false;
      merged.addAll(group.ids);
      if (mergedName.isEmpty) mergedName = group.name;
      return true;
    });
    _groups.add(_BlockedSeller(merged, mergedName));
    notifyListeners();
  }

  void unblock(String id, {String name = ''}) {
    final trimmed = id.trim();
    final normalized = name.trim().toLowerCase();
    final before = _groups.length;
    _groups.removeWhere(
      (group) =>
          (trimmed.isNotEmpty && group.ids.contains(trimmed)) ||
          (normalized.isNotEmpty && group.name == normalized),
    );
    if (_groups.length != before) notifyListeners();
  }

  /// Loads the saved block list once so search and the feed hide them
  /// after a restart, not only in the session that tapped block.
  Future<void> sync() {
    return _syncing ??= _loadSaved();
  }

  Future<void> _loadSaved() async {
    final uid = await AuthService.getCurrentUserId();
    if (uid == null || uid.isEmpty) return;
    final rows = await ModerationService.blockedUsers(uid);
    for (final row in rows) {
      block(
        [row['uid']?.toString() ?? '', row['id']?.toString() ?? ''],
        name: row['name']?.toString() ?? '',
      );
    }
  }
}

class ModerationService {
  static String get _sql => ApiConfigService.instance.sqlEndpoint;

  static Map<String, dynamic>? _decode(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is! String) return null;
    final text = raw.trim();
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final decoded = jsonDecode(text.substring(start, end + 1));
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> _post(Map<String, dynamic> fields) async {
    try {
      final response = await Dio().post(
        '$_sql?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(fields),
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return _decode(response.data) ?? {'success': false};
    } catch (_) {
      return {'success': false};
    }
  }

  static Future<Map<String, dynamic>> verifyReviewerPhone({
    required String phone,
    required String code,
  }) {
    return _post({
      'action': 'verify_reviewer_phone',
      'phone': phone,
      'code': code,
    });
  }

  static Future<Map<String, dynamic>> userByAppleId(String appleUserId) {
    return _post({
      'action': 'get_user_by_apple_id',
      'apple_user_id': appleUserId,
    });
  }

  static Future<void> linkAppleId({
    required String email,
    required String appleUserId,
  }) async {
    await _post({
      'action': 'link_apple_id',
      'email': email,
      'apple_user_id': appleUserId,
    });
  }

  static Future<void> acceptTerms(String uid) async {
    await _post({'action': 'accept_terms', 'uid': uid});
  }

  static Future<Map<String, dynamic>> report({
    required String userId,
    required String reason,
    String note = '',
    String targetType = 'product',
    String itemId = '',
    String commentId = '',
    String targetUid = '',
  }) {
    return _post({
      'action': 'add_report',
      'user_id': userId,
      'reason': reason,
      'note': note,
      'target_type': targetType,
      'item_id': itemId,
      'comment_id': commentId,
      'target_uid': targetUid,
    });
  }

  static Future<Map<String, dynamic>> blockUser({
    required String blockerUid,
    required String blockedUid,
    String reason = '',
  }) {
    return _post({
      'action': 'block_user',
      'blocker_uid': blockerUid,
      'blocked_uid': blockedUid,
      'reason': reason,
    });
  }

  static Future<Map<String, dynamic>> unblockUser({
    required String blockerUid,
    required String blockedUid,
  }) {
    return _post({
      'action': 'unblock_user',
      'blocker_uid': blockerUid,
      'blocked_uid': blockedUid,
    });
  }

  static Future<List<Map<String, dynamic>>> blockedUsers(String blockerUid) async {
    final result = await _post({
      'action': 'get_blocked_users',
      'blocker_uid': blockerUid,
    });
    final data = result['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Future<bool> containsBannedWords(String text) async {
    if (text.trim().isEmpty) return false;
    try {
      final result = await _post({
        'action': 'check_banned_words',
        'text': text,
      });
      return result['error']?.toString() == 'banned_word';
    } catch (_) {
      return false;
    }
  }
}
