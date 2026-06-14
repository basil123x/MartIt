import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:MartIt/core/services/apple_auth_service.dart';
import 'package:MartIt/core/services/avatar_service.dart';
import 'package:MartIt/core/services/google_auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:MartIt/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import 'phone_login_screen.dart';
import 'email_login_screen.dart';
import '../../core/utils/theme_extensions.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleAuthService googleAuthService = GoogleAuthService();
  bool _isAppleLoading = false;

  Future<void> _googleSignIn() async {
    try {
      User? user = await GoogleAuthService().signInWithGoogle();
      if (user != null) {
        int uid = 1000 + Random().nextInt(9000);
        int oid = 1000 + Random().nextInt(9000);

        await FlutterSecureStorage().write(
          key: "user_uid",
          value: uid.toString(),
        );
        await FlutterSecureStorage().write(
          key: "user_oid",
          value: oid.toString(),
        );
        await FlutterSecureStorage().write(
          key: 'social_name',
          value: user.displayName,
        );
        await FlutterSecureStorage().write(
          key: 'social_email',
          value: user.email,
        );
        await FlutterSecureStorage().write(
          key: 'social_avatar',
          value: user.photoURL,
        );
        await FlutterSecureStorage().write(key: "login_type", value: "Google");

        String? playerId = OneSignal.User.pushSubscription.id;

        var result = await Dio().post(
          "https://www.globee-trading.com/app2026/sql.php?k=${DateTime.now().millisecond}",
          data: FormData.fromMap({
            "action": "create_account",
            "uid": uid,
            "oid": oid,
            "name": user.displayName,
            "email": user.email,
            "phone": "",
            "player_id": playerId,
            "store_id": "1",
            "login_type": "Google",
          }),
        );

        // ← أضف الـ print دي
        print('🔥 API Response: ${result.data}');

        if (result.data['success'] == true) {
          final userId = await FlutterSecureStorage().read(key: "user_uid");
          await AvatarService.uploadSocialPhotoIfNeeded(
            userId: userId ?? "",
            photoUrl: user.photoURL,
          );

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => SplashScreen()),
            );
          }
        } else {
          if (result.data['success'] == false) {
            final existingUid = result.data['uid']['uid'].toString();
            await FlutterSecureStorage().write(
              key: "user_uid",
              value: existingUid,
            );
            await FlutterSecureStorage().write(
              key: "user_oid",
              value: result.data['uid']['oid'].toString(),
            );
            await FlutterSecureStorage().write(
              key: 'social_name',
              value: user.displayName,
            );
            await FlutterSecureStorage().write(
              key: 'social_email',
              value: user.email,
            );
            await FlutterSecureStorage().write(
              key: 'social_avatar',
              value: user.photoURL,
            );
            await FlutterSecureStorage().write(
              key: "login_type",
              value: "Google",
            );

            final userId = await FlutterSecureStorage().read(key: "user_uid");
            await AvatarService.uploadSocialPhotoIfNeeded(
              userId: userId ?? "",
              photoUrl: user.photoURL,
            );

            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => SplashScreen()),
              );
            }
          } else {
            if (mounted) {
              showAppSnackbar(
                context,
                message: 'API Error: ${result.data}',
                type: SnackType.error,
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error: $e');
      showAppSnackbar(context, message: "Error: $e", type: SnackType.error);
    }
  }

  Future<void> _appleSignIn() async {
    if (_isAppleLoading) return;

    setState(() {
      _isAppleLoading = true;
    });

    try {
      final result = await AppleAuthService.signIn();
      if (result == null) {
        return;
      }

      await AppleAuthService.saveSession(result);

      // Apple Sign In does not provide a profile photo URL — skip upload.
      final userId = await FlutterSecureStorage().read(key: "user_uid");
      await AvatarService.uploadSocialPhotoIfNeeded(
        userId: userId ?? "",
        photoUrl: null,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled && mounted) {
        showAppSnackbar(context, message: "Error: $e", type: SnackType.error);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, message: "Error: $e", type: SnackType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
      backgroundColor: context.appSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Image.asset(
                    "assets/images/app-icon2.png",
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 20),

                // App Name
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
                  lang == 'ar'
                      ? 'مرحباً بك في عالم التسوق الذكي'
                      : 'Welcome to the Smart Shopping World',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondaryColor(context),
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 30),

                _buildLoginOptionButton(
                  context: context,
                  imageTxt: "assets/images/social/google.png",
                  isimg: true,
                  title: lang == 'ar' ? 'سجل بواسطة جوجل' : 'Sign in with Google',
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  onTap: () => _googleSignIn(),
                ),

                const SizedBox(height: 16),

                Visibility(
                  visible: Platform.isIOS,
                  child: Column(
                    children: [
                      _buildLoginOptionButton(
                        context: context,
                        imageTxt: "assets/images/social/apple.png",
                        isimg: true,
                        title: _isAppleLoading
                            ? (lang == 'ar' ? 'جاري التحميل' : 'Loading')
                            : (lang == 'ar'
                                ? 'سجل بواسطة أبل'
                                : 'Sign in with Apple'),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        onTap: _isAppleLoading ? null : _appleSignIn,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                _buildLoginOptionButton(
                  context: context,
                  icon: Iconsax.mobile,
                  isimg: false,
                  title: lang == 'ar'
                      ? 'التسجيل برقم الهاتف'
                      : 'Sign in with Phone',
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

                // Email Login Button
                _buildLoginOptionButton(
                  context: context,
                  icon: Iconsax.sms,
                  isimg: false,
                  title: lang == 'ar'
                      ? 'التسجيل بالبريد الإلكتروني'
                      : 'Sign in with Email',
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
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

                Opacity(
                  opacity: 0.4,
                  child: _buildLoginOptionButton(
                    context: context,
                    imageTxt: "assets/images/social/face.png",
                    isimg: true,
                    title: lang == 'ar'
                        ? 'سجل بواسطة الفيسبوك'
                        : 'Sign in with Facebook',
                    subtitle: lang == 'ar' ? 'قريباً' : 'Coming Soon',
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                // Footer
                Text(
                  lang == 'ar'
                      ? 'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية'
                      : 'By continuing, you agree to our Terms and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
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
        textDirection: LocalizationService.instance.textDirection,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    : Image.asset(imageTxt ?? "", width: 20),
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
                          visible: subtitle != null ? true : false,
                          child: Text(
                            subtitle ?? "",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    Icon(
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

  Widget _buildSocialButton({
    required BuildContext context,
    required String icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
        color: context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightGrey, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(child: Image.asset(icon, width: 32, height: 32)),
      ),
    );
  }
}
