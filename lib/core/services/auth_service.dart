import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _uidKey = 'user_uid';
  static const String _phoneKey = 'user_phone';
  static const String _nameKey = 'user_name';
  static const String _emailKey = 'user_email';
  static const String _profileImageKey = 'user_profile_image';
  static const String baseUrl = 'https://www.Globee-Trading.com/app2026';

  /// GlobalFarm (MartIt) store id — send on all account-related API actions.
  static const String globalFarmStoreId = '2';

  /// Include on every user registration API request body.
  static Map<String, String> registrationStoreFields() => {
        'store_id': globalFarmStoreId,
      };

  /// Ensures an existing user is linked to GlobalFarm (store 2) after login.
  static Future<void> ensureUserStoreId(String uid) async {
    if (uid.isEmpty) return;
    try {
      await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'set_user_store_id',
          'uid': uid,
          'store_id': globalFarmStoreId,
        }),
      );
    } catch (_) {}
  }

  // SharedPreferences session keys (used by Google / social login)
  static const String prefsUid = 'uid';
  static const String prefsOid = 'oid';
  static const String prefsEmail = 'email';
  static const String prefsName = 'name';
  static const String prefsPhoto = 'photo';
  static const String prefsIsLoggedIn = 'isLoggedIn';
  static const String prefsLoginMethod = 'loginMethod';
  static const String prefsIdToken = 'idToken';
  static const String prefsAccessToken = 'accessToken';

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final uid = await _storage.read(key: _uidKey);
    if (uid != null && uid.isNotEmpty) return true;
    final prefs = await SharedPreferences.getInstance();
    final prefsUidValue = prefs.getString(prefsUid);
    return prefs.getBool(prefsIsLoggedIn) == true &&
        prefsUidValue != null &&
        prefsUidValue.isNotEmpty;
  }

  /// Normalizes API user payloads (`id` vs `uid`, etc.).
  static Map<String, String> normalizeUserData(Map<String, dynamic> raw) {
    return {
      'id': raw['id']?.toString() ?? raw['uid']?.toString() ?? '',
      'oid': raw['oid']?.toString() ?? '',
      'name':
          raw['name']?.toString() ?? raw['Fullname']?.toString() ?? '',
      'email':
          raw['email']?.toString() ?? raw['Email']?.toString() ?? '',
    };
  }

  /// Writes session to FlutterSecureStorage + SharedPreferences.
  /// Returns true only when [serverUid] is persisted and readable.
  static Future<bool> persistLoginSession({
    required String serverUid,
    required String serverOid,
    required String email,
    required String name,
    String? photoUrl,
    required String loginMethod,
    String? firebaseUid,
    String? idToken,
    String? accessToken,
  }) async {
    if (serverUid.isEmpty) return false;

    await _storage.write(key: _uidKey, value: serverUid);
    await _storage.write(key: 'user_oid', value: serverOid);
    await _storage.write(key: _nameKey, value: name);
    if (email.isNotEmpty) {
      await _storage.write(key: _emailKey, value: email);
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await _storage.write(key: _profileImageKey, value: photoUrl);
    }
    if (firebaseUid != null && firebaseUid.isNotEmpty) {
      await _storage.write(key: 'firebase_uid', value: firebaseUid);
    }
    if (idToken != null && idToken.isNotEmpty) {
      await _storage.write(key: 'google_id_token', value: idToken);
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      await _storage.write(key: 'google_access_token', value: accessToken);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsUid, serverUid);
    await prefs.setString(prefsOid, serverOid);
    await prefs.setString(prefsEmail, email);
    await prefs.setString(prefsName, name);
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await prefs.setString(prefsPhoto, photoUrl);
    }
    await prefs.setBool(prefsIsLoggedIn, true);
    await prefs.setString(prefsLoginMethod, loginMethod);
    if (idToken != null && idToken.isNotEmpty) {
      await prefs.setString(prefsIdToken, idToken);
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      await prefs.setString(prefsAccessToken, accessToken);
    }

    await ensureUserStoreId(serverUid);

    return verifySessionSaved(expectedUid: serverUid);
  }

  /// Confirms uid was written to secure storage and SharedPreferences.
  static Future<bool> verifySessionSaved({required String expectedUid}) async {
    final secureUid = await _storage.read(key: _uidKey);
    final prefs = await SharedPreferences.getInstance();
    final prefsUidValue = prefs.getString(prefsUid);
    final loggedIn = prefs.getBool(prefsIsLoggedIn) == true;
    final secureOk = secureUid == expectedUid;
    final prefsOk = prefsUidValue == expectedUid && loggedIn;
    return secureOk || prefsOk;
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

  /// Returns user row as `{ id, oid, name, email }` when the email exists in DB.
  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'get_user_by_email',
          'email': trimmed,
        }),
      );
      final body = response.data;
      if (body is! Map) return null;
      final map = Map<String, dynamic>.from(body);
      if (map['success'] == true && map['data'] != null) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveSessionFromUserData(
    Map<String, dynamic> data, {
    String? emailOverride,
    String loginMethod = 'email',
    String? photoUrl,
    String? firebaseUid,
    String? idToken,
    String? accessToken,
  }) async {
    final normalized = normalizeUserData(data);
    final email = emailOverride ?? normalized['email'] ?? '';
    return persistLoginSession(
      serverUid: normalized['id'] ?? '',
      serverOid: normalized['oid'] ?? '',
      email: email,
      name: normalized['name'] ?? '',
      photoUrl: photoUrl,
      loginMethod: loginMethod,
      firebaseUid: firebaseUid,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  static Future<void> updateFcmTokenForEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    try {
      final String? userId = OneSignal.User.pushSubscription.id;
      await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'update_fcm_token',
          'email': trimmed,
          'fcm_token': userId ?? '',
        }),
      );
    } catch (_) {}
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
    await Dio().post(
      '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
      data: FormData.fromMap({
        'action': 'create_account',
        'uid': uid,
        'oid': oid,
        'name': name,
        'phone': phone,
        'player_id': userId,
        'login_type': 'Phone',
        ...registrationStoreFields(),
      }),
    );

    await ensureUserStoreId(uid.toString());

    await _storage.write(key: _uidKey, value: uid.toString());
    await _storage.write(key: "user_oid", value: oid.toString());
    await _storage.write(key: _phoneKey, value: phone);
    await _storage.write(key: _nameKey, value: name);

    if (profileImage != null) {
      await _storage.write(key: _profileImageKey, value: profileImage);
    }

    File file = File(profileImage ?? "");

    List<int> fileBytes = await file.readAsBytes();

    await Dio().put(
      "https://storage.bunnycdn.com/globee-trading/users/$uid/avatar.jpg",
      data: Stream.fromIterable([fileBytes]),
      options: Options(
        headers: {
          "AccessKey": "18808acb-f5f1-473e-bd84cf669411-20c0-499c",
          "Content-Type": "application/octet-stream",
        },
      ),
    );
  }

  static Future getUserStatus(uid) async {
    var request = await Dio().post(
      '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
      data: FormData.fromMap({"action": "user_status", "uid": uid}),
    );
    if (request.statusCode == 200) {
      return request.data;
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
        final String serverUid = response.data['data']['id'].toString();
        await _storage.write(key: _uidKey, value: serverUid);
        await _storage.write(
          key: 'user_oid',
          value: response.data['data']['oid'],
        );
        await Dio().post(
          '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
          data: FormData.fromMap({
            'action': 'get_user_details',
            'id': serverUid,
            'oid': response.data['data']['oid'],
            'fcm_token': userId,
          }),
        );
        await ensureUserStoreId(serverUid);
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
        return response.data['success'];
      } else {
        return response.data['success'];
      }
    } else {
      throw Exception('Failed to load items: ${response.statusCode}');
    }
  }

  // Logout
  static Future<void> logout() async {
    await _storage.delete(key: _uidKey);
    await _storage.delete(key: 'user_oid');
    await _storage.delete(key: _phoneKey);
    await _storage.delete(key: _nameKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _profileImageKey);
    await _storage.delete(key: 'firebase_uid');
    await _storage.delete(key: 'google_id_token');
    await _storage.delete(key: 'google_access_token');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsUid);
    await prefs.remove(prefsOid);
    await prefs.remove(prefsEmail);
    await prefs.remove(prefsName);
    await prefs.remove(prefsPhoto);
    await prefs.remove(prefsIsLoggedIn);
    await prefs.remove(prefsLoginMethod);
    await prefs.remove(prefsIdToken);
    await prefs.remove(prefsAccessToken);
  }

  // Update profile image
  static Future<void> updateProfileImage(String imagePath) async {
    await _storage.write(key: _profileImageKey, value: imagePath);
  }

  // Update user name
  static Future<void> updateUserName(String name) async {
    await _storage.write(key: _nameKey, value: name);
  }
}
