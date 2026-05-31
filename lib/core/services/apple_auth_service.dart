import "dart:math";

import "package:dio/dio.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:onesignal_flutter/onesignal_flutter.dart";
import "package:sign_in_with_apple/sign_in_with_apple.dart";

class AppleAuthResult {
  final String uid;
  final String oid;
  final String email;
  final String name;

  const AppleAuthResult({
    required this.uid,
    required this.oid,
    required this.email,
    required this.name,
  });
}

class AppleAuthService {
  static const String _apiUrl =
      "https://www.Globee-Trading.com/app2026/sql.php";
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _cacheKey(String userIdentifier, String field) {
    return "apple_${userIdentifier}_$field";
  }

  static Future<AppleAuthResult?> signIn() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final userIdentifier = credential.userIdentifier ?? "";
    if (userIdentifier.isEmpty) {
      throw Exception("Apple user identifier is missing");
    }

    String? email = credential.email;
    if (email != null && email.isNotEmpty) {
      await _storage.write(
        key: _cacheKey(userIdentifier, "email"),
        value: email,
      );
    } else {
      email = await _storage.read(key: _cacheKey(userIdentifier, "email"));
    }

    if (email == null || email.isEmpty) {
      throw Exception("Apple email is unavailable. Sign in with Apple again.");
    }

    String fullName = "";
    final givenName = credential.givenName ?? "";
    final familyName = credential.familyName ?? "";
    if (givenName.isNotEmpty || familyName.isNotEmpty) {
      fullName = "$givenName $familyName".trim();
      await _storage.write(
        key: _cacheKey(userIdentifier, "name"),
        value: fullName,
      );
    } else {
      fullName =
          await _storage.read(key: _cacheKey(userIdentifier, "name")) ?? "";
    }

    if (fullName.isEmpty) {
      fullName = email.contains("@") ? email.split("@").first : "Apple User";
    }

    final cacheBust =
        "$_apiUrl?k=${DateTime.now().millisecondsSinceEpoch}";
    final checkResponse = await Dio().post(
      cacheBust,
      data: FormData.fromMap({
        "action": "get_user_by_email",
        "email": email,
      }),
    );

    if (checkResponse.data["success"] != true) {
      throw Exception("Failed to verify Apple account");
    }

    if (checkResponse.data["exists"] == true) {
      final userData = checkResponse.data["data"] as Map<String, dynamic>;
      await _updateFcmToken(email);
      return AppleAuthResult(
        uid: userData["uid"]?.toString() ?? "",
        oid: userData["oid"]?.toString() ?? "",
        email: userData["Email"]?.toString() ?? email,
        name: userData["Fullname"]?.toString() ?? fullName,
      );
    }

    final uid = (1000 + Random().nextInt(9000)).toString();
    final oid = (1000 + Random().nextInt(9000)).toString();
    String? playerId = OneSignal.User.pushSubscription.id;

    final createResponse = await Dio().post(
      cacheBust,
      data: FormData.fromMap({
        "action": "create_social_account",
        "name": fullName,
        "email": email,
        "login_type": "Apple",
        "player_id": playerId ?? "",
        "avatar_url": "",
      }),
    );

    if (createResponse.data["success"] != true) {
      throw Exception(
        createResponse.data["message"]?.toString() ??
            createResponse.data["error"]?.toString() ??
            "Failed to create Apple account",
      );
    }

    await _updateFcmToken(email);

    final data = createResponse.data["data"] as Map<String, dynamic>?;
    return AppleAuthResult(
      uid: data?["id"]?.toString() ?? uid,
      oid: data?["oid"]?.toString() ?? oid,
      email: data?["email"]?.toString() ?? email,
      name: data?["name"]?.toString() ?? fullName,
    );
  }

  static Future<void> saveSession(AppleAuthResult result) async {
    await _storage.write(key: "user_uid", value: result.uid);
    await _storage.write(key: "user_oid", value: result.oid);
    await _storage.write(key: "user_email", value: result.email);
    await _storage.write(key: "user_name", value: result.name);
  }

  static Future<void> _updateFcmToken(String email) async {
    String? playerId = OneSignal.User.pushSubscription.id;
    await Dio().post(
      "$_apiUrl?k=${DateTime.now().millisecondsSinceEpoch}",
      data: FormData.fromMap({
        "action": "update_fcm_token",
        "email": email,
        "fcm_token": playerId,
      }),
    );
  }
}
