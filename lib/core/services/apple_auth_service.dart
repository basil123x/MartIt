import 'dart:convert';
import 'dart:math';

import 'package:Albadaa/core/services/social_auth_service.dart';
import 'package:Albadaa/features/splash/splash_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

String generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String sha256ofString(String input) {
  final bytes = utf8.encode(input);
  return sha256.convert(bytes).toString();
}

Future<void> signInWithApple(BuildContext context) async {
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

    final userIdentifier = credential.userIdentifier ?? '';
    final identityToken = credential.identityToken ?? '';
    final firstName = credential.givenName ?? '';
    final lastName = credential.familyName ?? '';
    final emailFromApple = credential.email ?? '';
    final fullNameFromApple = '$firstName $lastName'.trim();

    await socialAuthStorage.write(key: 'apple_id', value: userIdentifier);
    await socialAuthStorage.write(key: 'apple_token', value: identityToken);

    if (emailFromApple.isNotEmpty) {
      await socialAuthStorage.write(key: 'social_email', value: emailFromApple);
    }
    if (fullNameFromApple.isNotEmpty) {
      await socialAuthStorage.write(key: 'social_name', value: fullNameFromApple);
    }

    final email =
        emailFromApple.isNotEmpty
            ? emailFromApple
            : (await socialAuthStorage.read(key: 'social_email') ?? '');
    final fullName =
        fullNameFromApple.isNotEmpty
            ? fullNameFromApple
            : (await socialAuthStorage.read(key: 'social_name') ?? 'Apple User');

    if (email.isEmpty) {
      throw Exception(
        'Apple did not provide an email. Sign out of Apple ID for this app and try again.',
      );
    }

    final playerId = OneSignal.User.pushSubscription.id;
    final userData = await resolveSocialUserByEmail(
      email: email,
      name: fullName,
      loginType: 'Apple',
      playerId: playerId,
    );

    final ids = parseSocialUserIds(userData);
    await persistSocialAuthSession(
      uid: ids.uid,
      oid: ids.oid,
      email: email,
      name: userData['name']?.toString() ?? fullName,
    );

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
    );
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code != AuthorizationErrorCode.canceled && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple sign in failed: ${e.code.name}')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple sign in error: $e')),
      );
    }
  }
}
