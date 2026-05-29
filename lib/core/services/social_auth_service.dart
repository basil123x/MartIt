import 'package:BML/core/constants/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const socialAuthStorage = FlutterSecureStorage();
const socialAuthSqlUrl = 'https://www.globee-trading.com/app2026/sql.php';

Map<String, dynamic>? socialAuthAsMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

Future<Map<String, dynamic>> postSocialAuthSql(
  Map<String, dynamic> fields,
) async {
  final result = await Dio().post(
    '$socialAuthSqlUrl?k=${DateTime.now().millisecondsSinceEpoch}',
    data: FormData.fromMap(fields),
  );
  final body = socialAuthAsMap(result.data);
  if (body == null) {
    throw Exception('Invalid API response');
  }
  return body;
}

/// Lookup by email, or create via create_social_account. Never uses phone endpoints.
Future<Map<String, dynamic>> resolveSocialUserByEmail({
  required String email,
  required String name,
  required String loginType,
  String? playerId,
  String? avatarUrl,
  String storeId = AppConstants.albadaaStoreId,
}) async {
  final lookup = await postSocialAuthSql({
    'action': 'get_user_by_email',
    'email': email,
  });

  if (lookup['success'] == true) {
    final data = socialAuthAsMap(lookup['data']);
    if (data != null) {
      return data;
    }
  }

  final created = await postSocialAuthSql({
    'action': 'create_social_account',
    'name': name.isNotEmpty ? name : loginType,
    'email': email,
    'avatar_url': avatarUrl ?? '',
    'player_id': playerId ?? '',
    'login_type': loginType,
    'store_id': storeId,
  });

  if (created['success'] == true) {
    final data = socialAuthAsMap(created['data']);
    if (data != null) {
      return data;
    }
  }

  final retry = await postSocialAuthSql({
    'action': 'get_user_by_email',
    'email': email,
  });
  if (retry['success'] == true) {
    final data = socialAuthAsMap(retry['data']);
    if (data != null) {
      return data;
    }
  }

  throw Exception(
    created['error']?.toString() ??
        created['message']?.toString() ??
        '$loginType login failed',
  );
}

Future<void> persistSocialAuthSession({
  required String uid,
  required String oid,
  required String email,
  required String name,
  String? avatarUrl,
}) async {
  await socialAuthStorage.write(key: 'user_uid', value: uid);
  await socialAuthStorage.write(key: 'user_oid', value: oid);
  await socialAuthStorage.write(key: 'social_email', value: email);
  await socialAuthStorage.write(key: 'social_name', value: name);
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    await socialAuthStorage.write(key: 'social_avatar', value: avatarUrl);
  }
}

/// Returns uid/oid from API data map, or throws if missing.
({String uid, String oid}) parseSocialUserIds(Map<String, dynamic> data) {
  final uid = data['id']?.toString() ?? '';
  final oid = data['oid']?.toString() ?? '';
  if (uid.isEmpty) {
    throw Exception('Login failed');
  }
  return (uid: uid, oid: oid);
}
