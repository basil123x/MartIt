import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _uidKey = 'user_uid';
  static const String _phoneKey = 'user_phone';
  static const String _nameKey = 'user_name';
  static const String _profileImageKey = 'user_profile_image';
  static const String baseUrl = 'https://www.Globee-Trading.com/app2026';

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
    await Dio().post(
      '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
      data: FormData.fromMap({
        "action": "create_account",
        "uid": uid,
        "oid": oid,
        "name": name,
        "phone": phone,
        "player_id": userId,
        "login_type": "Phone",
      }),
    );

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
    await _storage.delete(key: _phoneKey);
    await _storage.delete(key: _nameKey);
    await _storage.delete(key: _profileImageKey);
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
