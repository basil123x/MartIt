import 'dart:math';

import 'package:GES/features/auth/create_account_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

Future signInWithApple(BuildContext context) async {
  try {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final String userIdentifier = credential.userIdentifier!;
    final String identityToken = credential.identityToken!;
    await FlutterSecureStorage().write(key: 'apple_id', value: userIdentifier);
    await FlutterSecureStorage().write(key: 'apple_token', value: identityToken);
    
    Navigator.push(context, MaterialPageRoute(builder: (context) => CreateAccountScreen(loginType: "Apple")));

  } on SignInWithAppleAuthorizationException catch (e) {
    switch (e.code) {
      case AuthorizationErrorCode.canceled:
        // المستخدم ضغط كانسل
        break;
      case AuthorizationErrorCode.failed:
        // فشل التسجيل
        break;
      case AuthorizationErrorCode.notHandled:
      case AuthorizationErrorCode.unknown:
        // خطأ غير متوقع
        break;
      default:
        break;
    }
  }
}