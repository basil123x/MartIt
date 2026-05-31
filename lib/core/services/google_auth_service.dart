import 'package:BML/core/services/social_auth_service.dart';
import 'package:BML/features/splash/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class GoogleAuthService {
  Future<User?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      await GoogleSignIn.instance.signOut().catchError((_) {});

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final User? user = userCredential.user;
      print('✅ Name: ${user?.displayName}');
      print('✅ Email: ${user?.email}');
      print('✅ UID: ${user?.uid}');
      return user;
    } catch (e) {
      print('❌ Google Sign In Error: $e');

      if (e.toString().contains('canceled')) {
        return null;
      }

      throw Exception('فشل تسجيل الدخول، حاول تاني');
    }
  }

  Future<void> signInWithGoogleAndComplete(BuildContext context) async {
    final user = await signInWithGoogle();
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تسجيل الدخول، حاول مرة تانية')),
        );
      }
      return;
    }

    final email = user.email ?? '';
    if (email.isEmpty) {
      throw Exception('Google did not provide an email address');
    }

    final name = user.displayName ?? 'Google User';
    final avatarUrl = user.photoURL;
    final playerId = OneSignal.User.pushSubscription.id;

    final userData = await resolveSocialUserByEmail(
      email: email,
      name: name,
      loginType: 'Google',
      playerId: playerId,
      avatarUrl: avatarUrl,
    );

    final ids = parseSocialUserIds(userData);
    await persistSocialAuthSession(
      uid: ids.uid,
      oid: ids.oid,
      email: email,
      name: userData['name']?.toString() ?? name,
      avatarUrl: avatarUrl,
    );

    print('🔥 Google login uid=${ids.uid} oid=${ids.oid}');

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
    );
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
