import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'api_config_service.dart';
import 'moderation_service.dart';
import 's3_upload_service.dart';
import 'terms_acceptance_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _uidKey = 'user_uid';
  static const String _phoneKey = 'user_phone';
  static const String _nameKey = 'user_name';
  static const String _profileImageKey = 'user_profile_image';
  static String get baseUrl => ApiConfigService.instance.apiBaseUrl;

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final uid = await _storage.read(key: _uidKey);
    return uid != null && uid.isNotEmpty;
  }

  // Get current user UID
  static Future<String?> getCurrentUID() async {
    return await _storage.read(key: _uidKey);
  }

  // Get current user ID (alias for getCurrentUID)
  static Future<String?> getCurrentUserId() async {
    return await getCurrentUID();
  }

  // Get current user OID
  static Future<String?> getCurrentOID() async {
    return await _storage.read(key: 'user_oid');
  }

  // Get current user phone
  static Future<String?> getCurrentPhone() async {
    return await _storage.read(key: _phoneKey);
  }

  // Get current user name
  static Future<String?> getCurrentName() async {
    return await _storage.read(key: _nameKey);
  }

  // Get current user profile image
  static Future<String?> getCurrentProfileImage() async {
    return await _storage.read(key: _profileImageKey);
  }

  // Generate random OTP
  static String generateOTP() {
    final random = Random();
    String otp = '';
    for (int i = 0; i < 6; i++) {
      otp += random.nextInt(10).toString();
    }
    print('Generated OTP: $otp'); // For development purposes
    return otp;
  }

  // Validate Qatar phone number (8 digits)
  static bool isValidQatarPhone(String phone) {
    // Remove any spaces or special characters
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleanPhone.length == 8 && RegExp(r'^\d{8}$').hasMatch(cleanPhone);
  }

  // Login with phone number
  static Future<void> createWithPhone(
    String phone,
    String name, {
    String? profileImage,
  }) async {
    final uid = 1000 + Random().nextInt(9000);
    final oid = 1000 + Random().nextInt(9000);
    String? userId = OneSignal.User.pushSubscription.id;

    await _storage.write(key: _uidKey, value: uid.toString());
    await _storage.write(key: "user_oid", value: oid.toString());

    String? avatarUrl;
    if (profileImage != null) {
      final storedUid = await _storage.read(key: _uidKey);
      avatarUrl = await S3UploadService.uploadProfileImage(
        userId: storedUid ?? uid.toString(),
        filePath: profileImage,
      );
      if (avatarUrl != null) {
        await _storage.write(key: _profileImageKey, value: avatarUrl);
      }
    }

    await Dio().post(
      "$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
      data: FormData.fromMap({
        "action": "create_account",
        "uid": uid,
        "oid": oid,
        "name": name,
        "phone": phone,
        "player_id": userId,
        "login_type": "Phone",
        "avatar_url": avatarUrl ?? "",
        "store_id": "1",
      }),
    );

    await _storage.write(key: _phoneKey, value: phone);
    await _storage.write(key: _nameKey, value: name);
    await _storage.write(key: "login_type", value: "Phone");
  }

  static Future<void> updateUserAvatarUrl({
    required String uid,
    required String avatarUrl,
  }) async {
    await Dio().post(
      "$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
      data: FormData.fromMap({
        "action": "update_user_avatar",
        "uid": uid,
        "avatar_url": avatarUrl,
      }),
    );
  }

  /// Returns `{success, status}` or `{success: false, error}` — never throws.
  static Future<Map<String, dynamic>> getUserStatus(dynamic uid) async {
    if (uid == null || uid.toString().isEmpty) {
      return {'success': false, 'error': 'uid missing', 'status': null};
    }
    try {
      final request = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({"action": "user_status", "uid": uid.toString()}),
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (code) => code != null && code < 500,
        ),
      );
      final raw = request.data?.toString().trim() ?? '';
      if (raw.isEmpty) {
        return {'success': false, 'error': 'empty response', 'status': null};
      }
      // Strip accidental PHP warnings before the JSON object.
      final jsonStart = raw.indexOf('{');
      if (jsonStart < 0) {
        return {
          'success': false,
          'error': 'non-json response',
          'status': null,
          'raw': raw.length > 200 ? raw.substring(0, 200) : raw,
        };
      }
      final decoded = jsonDecode(raw.substring(jsonStart));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {'success': false, 'error': 'invalid payload', 'status': null};
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'status': null};
    }
  }

  static Future loginWithPhone(String phone) async {
    String? userId = OneSignal.User.pushSubscription.id;
    final response = await Dio().post(
      '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
      data: FormData.fromMap({"action": "get_user_details", "phone": phone}),
    );

    if (response.statusCode == 200) {
      if (response.data['success'] == true) {
        await _storage.write(key: _uidKey, value: response.data['data']['id']);
        await _storage.write(
          key: 'user_oid',
          value: response.data['data']['oid'],
        );
        await Dio().post(
          '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
          data: FormData.fromMap({
            "action": "get_user_details",
            "id": response.data['data']['id'],
            "oid": response.data['data']['oid'],
            "fcm_token": userId,
          }),
        );
        await _storage.write(
          key: _phoneKey,
          value: response.data['data']['phone'],
        );
        await _storage.write(
          key: _nameKey,
          value: response.data['data']['name'],
        );
        if (response.data['data']['avatar'] != null) {
          await _storage.write(
            key: _profileImageKey,
            value: response.data['data']['avatar'],
          );
        }
        await _storage.write(key: "login_type", value: "Phone");
        return response.data['success'];
      } else {
        return response.data['success'];
      }
    } else {
      throw Exception('Failed to load items: ${response.statusCode}');
    }
  }

  // Logout — clear all session keys so the next login starts fresh
  static Future<void> logout() async {
    const keys = [
      _uidKey,
      'user_oid',
      'user_email',
      'social_email',
      'social_name',
      'social_avatar',
      _nameKey,
      _phoneKey,
      _profileImageKey,
      'login_type',
    ];
    for (final key in keys) {
      await _storage.delete(key: key);
    }
    await TermsAcceptanceService.clear();
    BlockedSellers.instance.clearSession();
  }

  /// Overwrite cached session with authoritative API user data.
  static Future<void> syncSessionFromApi({
    required String uid,
    String? oid,
    String? name,
    String? phone,
  }) async {
    if (uid.isEmpty) return;
    await _storage.write(key: _uidKey, value: uid);
    if (oid != null && oid.isNotEmpty) {
      await _storage.write(key: 'user_oid', value: oid);
    }
    if (name != null && name.isNotEmpty) {
      await updateUserName(name);
    }
    if (phone != null && phone.isNotEmpty) {
      await updateUserPhone(phone);
    }
  }

  // Update profile image
  static Future<void> updateProfileImage(String imagePath) async {
    await _storage.write(key: _profileImageKey, value: imagePath);
  }

  // Update user name
  static Future<void> updateUserName(String name) async {
    await _storage.write(key: _nameKey, value: name);
  }

  // Update user phone
  static Future<void> updateUserPhone(String phone) async {
    await _storage.write(key: _phoneKey, value: phone);
  }

  // Social login profile photo (Google/Apple)
  static Future<String?> getSocialAvatar() async {
    return await _storage.read(key: "social_avatar");
  }
}
