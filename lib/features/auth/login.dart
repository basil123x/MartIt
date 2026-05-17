import 'dart:io';

import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/google_auth_service.dart';
import 'package:GlobalFarm/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import 'phone_login_screen.dart';
import 'email_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  String _appleEmailCacheKey(String appleUserId) =>
      'apple_cached_email_$appleUserId';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Persists server session + optional Google profile/tokens, then navigates.
  Future<bool> _completeLoginAndNavigate({
    required Map<String, dynamic> serverUser,
    required String email,
    required String displayName,
    String? photoUrl,
    required String loginMethod,
    String? firebaseUid,
    String? idToken,
    String? accessToken,
  }) async {
    final normalized = AuthService.normalizeUserData(serverUser);
    final serverUid = normalized['id'] ?? '';
    if (serverUid.isEmpty) {
      _showSnack('لم يتم استلام معرف المستخدم من الخادم');
      return false;
    }

    if (email.isNotEmpty) {
      await AuthService.updateFcmTokenForEmail(email);
    }

    final saved = await AuthService.persistLoginSession(
      serverUid: serverUid,
      serverOid: normalized['oid'] ?? '',
      email: email,
      name: (normalized['name'] ?? '').isNotEmpty
          ? normalized['name']!
          : displayName,
      photoUrl: photoUrl,
      loginMethod: loginMethod,
      firebaseUid: firebaseUid,
      idToken: idToken,
      accessToken: accessToken,
    );

    if (!saved) {
      _showSnack('تعذر حفظ بيانات الجلسة. حاول مرة أخرى.');
      return false;
    }

    if (!mounted) return false;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
    );
    return true;
  }

  Future<Map<String, dynamic>?> _resolveServerUserForGoogle({
    required String email,
    required String displayName,
    required String photoUrl,
    required String? playerId,
  }) async {
    final Map<String, dynamic>? existing =
        await AuthService.getUserByEmail(email);
    if (existing != null) {
      return existing;
    }

    final Response<dynamic> result = await Dio().post(
      '${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
      data: FormData.fromMap({
        'action': 'create_social_account',
        'name': displayName,
        'email': email,
        'avatar_url': photoUrl,
        'player_id': playerId ?? '',
        'login_type': 'Google',
        ...AuthService.registrationStoreFields(),
      }),
    );

    final dynamic body = result.data;
    if (body is Map && body['success'] == true && body['data'] != null) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }

    // Account may already exist if get_user_by_email is missing on server.
    final Map<String, dynamic>? retry =
        await AuthService.getUserByEmail(email);
    if (retry != null) return retry;

    return null;
  }

  Future<void> _googleSignIn() async {
    try {
      final GoogleSignInResult? signInResult =
          await GoogleAuthService().signInWithGoogle();
      if (signInResult == null) {
        _showSnack('فشل تسجيل الدخول، حاول مرة تانية');
        return;
      }

      final String? email = signInResult.email;
      if (email == null || email.isEmpty) {
        _showSnack('لا يوجد بريد إلكتروني مرتبط بحساب جوجل');
        return;
      }

      final String displayName =
          signInResult.displayName ?? 'Google User';
      final String photoUrl = signInResult.photoUrl ?? '';
      final String? playerId = OneSignal.User.pushSubscription.id;

      final Map<String, dynamic>? serverUser =
          await _resolveServerUserForGoogle(
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        playerId: playerId,
      );

      if (serverUser == null) {
        _showSnack('فشل مزامنة الحساب مع الخادم');
        return;
      }

      await _completeLoginAndNavigate(
        serverUser: serverUser,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        loginMethod: 'google',
        firebaseUid: signInResult.firebaseUid,
        idToken: signInResult.idToken,
        accessToken: signInResult.accessToken,
      );
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _appleSignIn() async {
    if (!Platform.isIOS) return;

    try {
      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final String? appleUserId = credential.userIdentifier;
      if (appleUserId == null || appleUserId.isEmpty) {
        _showSnack('تعذر الحصول على معرف Apple.');
        return;
      }

      String? email = credential.email;
      if (email == null || email.isEmpty) {
        email = await _secureStorage.read(
          key: _appleEmailCacheKey(appleUserId),
        );
      }
      if (email == null || email.isEmpty) {
        _showSnack(
          'لم يتم استلام البريد من Apple. فعّل مشاركة البريد أو استخدم طريقة أخرى للدخول.',
        );
        return;
      }

      await _secureStorage.write(
        key: _appleEmailCacheKey(appleUserId),
        value: email,
      );

      String displayName =
          '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
      if (displayName.isEmpty) {
        displayName = 'Apple User';
      }

      Map<String, dynamic>? serverUser =
          await AuthService.getUserByEmail(email);
      if (serverUser == null) {
        final String? playerId = OneSignal.User.pushSubscription.id;
        final Response<dynamic> result = await Dio().post(
          '${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
          data: FormData.fromMap({
            'action': 'create_social_account',
            'name': displayName,
            'email': email,
            'avatar_url': '',
            'player_id': playerId ?? '',
            'login_type': 'Apple',
            ...AuthService.registrationStoreFields(),
          }),
        );
        final dynamic body = result.data;
        if (body is Map && body['success'] == true && body['data'] != null) {
          serverUser = Map<String, dynamic>.from(body['data'] as Map);
        } else {
          serverUser = await AuthService.getUserByEmail(email);
        }
      }

      if (serverUser == null) {
        _showSnack('فشل مزامنة الحساب مع الخادم');
        return;
      }

      await _completeLoginAndNavigate(
        serverUser: serverUser,
        email: email,
        displayName: displayName,
        photoUrl: '',
        loginMethod: 'apple',
      );
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Image.asset(
                      'assets/images/Logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  AppStrings.appName,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                ),

                const SizedBox(height: 12),

                Text(
                  'مرحباً بك في عالم التسوق الذكي',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                ),

                const SizedBox(height: 30),

                const SizedBox(height: 16),

                _buildLoginOptionButton(
                  context: context,
                  imageTxt: 'assets/images/social/google.png',
                  isimg: true,
                  title: 'سجل بواسطة جوجل',
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  onTap: () async => _googleSignIn(),
                ),

                const SizedBox(height: 16),

                _buildLoginOptionButton(
                  context: context,
                  icon: Iconsax.sms,
                  isimg: false,
                  title: 'التسجيل بالبريد الإلكتروني',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmailLoginScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                if (Platform.isIOS)
                  _buildLoginOptionButton(
                    context: context,
                    imageTxt: 'assets/images/social/apple.png',
                    isimg: true,
                    title: 'سجل بواسطة أبل',
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    onTap: () async => _appleSignIn(),
                  ),

                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: Container(height: 1, color: AppColors.lightGrey),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'أو تسجيل الدخول باستخدام',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                    Expanded(
                      child: Container(height: 1, color: AppColors.lightGrey),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                _buildLoginOptionButton(
                  context: context,
                  icon: Iconsax.mobile,
                  isimg: false,
                  title: 'التسجيل برقم الهاتف',
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  onTap: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PhoneLoginScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                Opacity(
                  opacity: 0.4,
                  child: _buildLoginOptionButton(
                    context: context,
                    imageTxt: 'assets/images/social/face.png',
                    isimg: true,
                    title: 'سجل بواسطة الفيسبوك',
                    subtitle: 'قريباً',
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                Text(
                  'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginOptionButton({
    required BuildContext context,
    IconData? icon,
    String? imageTxt,
    bool? isimg,
    required String title,
    String? subtitle,
    required Gradient gradient,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isimg != true
                    ? Icon(icon, color: Colors.white, size: 28)
                    : Image.asset(imageTxt ?? '', width: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Visibility(
                          visible: subtitle != null,
                          child: Text(
                            subtitle ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
