import 'dart:convert';
import 'dart:math';
import 'package:Albadaa/features/auth/create_account_screen.dart';
import 'package:Albadaa/features/splash/splash_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// بنعمل nonce عشان Apple تتأكد من الـ request
String generateNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

String sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

Future signInWithApple(BuildContext context) async {
  try {
    final rawNonce = generateNonce();
    final nonce = sha256ofString(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final String userIdentifier = credential.userIdentifier ?? '';
    final String identityToken = credential.identityToken ?? '';
    final String firstName = credential.givenName ?? '';
    final String lastName = credential.familyName ?? '';
    final String email = credential.email ?? '';
    final String fullName = '$firstName $lastName'.trim();

    final storage = FlutterSecureStorage();
    await storage.write(key: 'apple_id', value: userIdentifier);
    await storage.write(key: 'apple_token', value: identityToken);
    int uid = 1000 + Random().nextInt(9000);
    int oid = 1000 + Random().nextInt(9000);
    await FlutterSecureStorage().write(key: "user_uid", value: uid.toString());
    await FlutterSecureStorage().write(key: "user_oid", value: oid.toString());
    await FlutterSecureStorage().write(key: 'social_name', value: fullName);
    await FlutterSecureStorage().write(key: 'social_email', value: email);
    
    String? playerId = OneSignal.User.pushSubscription.id;
    
    var result = await Dio().post(
      "https://www.globee-trading.com/app2026/sql.php?k=${DateTime.now().millisecond}",
      data: FormData.fromMap({
        "action": "create_account",
        "uid": uid,
        "oid": oid,
        "name": fullName,
        "email": email,
        "player_id": playerId,
        "store_id": "4",
        "login_type": "Apple",
        "social_id": userIdentifier,
      }),
    );

    print(result.data);
    print(fullName);
    print(email);
    print(userIdentifier);

    if (result.data['success'] == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SplashScreen()),
      );
    } else {
      
      if (result.data['success'] == false) {
        await FlutterSecureStorage().write(key: "user_uid", value: result.data['api']['uid'].toString());
        await FlutterSecureStorage().write(key: "user_oid", value: result.data['api']['oid'].toString());
        await FlutterSecureStorage().write(key: 'social_name', value: result.data['api']['fullName'].toString());
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => SplashScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API Error: ${result.data}')),
        );
      }
    }

  } on SignInWithAppleAuthorizationException catch (e) {
    switch (e.code) {
      case AuthorizationErrorCode.canceled:
        break;
      case AuthorizationErrorCode.failed:
        break;
      default:
        break;
    }
  }
}