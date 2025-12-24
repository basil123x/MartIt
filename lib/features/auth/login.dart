import 'dart:async';
import 'dart:io';

import 'package:Globee/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:iconsax/iconsax.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
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
                // Logo
                Container(
                  width: 100,
                  height: 100,
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
                      "assets/images/Logo.png",
                      fit: BoxFit.contain,
                    ),
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
                  'مرحباً بك في عالم التسوق الذكي',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 30),

                // Phone Login Button
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PhoneLoginScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                _buildLoginOptionButton(
                  context: context,
                  imageTxt: "assets/images/social/google.png",
                  isimg: true,
                  title: 'سجل بواسطة جوجل',
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  onTap: () async {
                    String? social_name = await FlutterSecureStorage().read(
                      key: 'social_name',
                    );
                    String? social_email = await FlutterSecureStorage().read(
                      key: 'social_email',
                    );
                    String? social_avatar = await FlutterSecureStorage().read(
                      key: 'social_avatar',
                    );

                    if (social_name != null &&
                        social_email != null &&
                        social_avatar != null) {
                      var userCredential = await Dio().post(
                        "https://globee-trading.com/app2026/sql.php",
                        data: FormData.fromMap({
                          "action": "get_social_account",
                          "name": social_name,
                          "email": social_email,
                          "avatar_url": social_avatar,
                        }),
                      );
                      print(userCredential);
                      await FlutterSecureStorage().write(
                        key: "user_uid",
                        value: userCredential.data['data']['id'],
                      );
                      await FlutterSecureStorage().write(
                        key: "user_oid",
                        value: userCredential.data['data']['oid'],
                      );
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => SplashScreen()),
                      );
                    } else {
                      unawaited(
                        GoogleSignIn.instance.initialize(
                          serverClientId:
                              "736610217893-4biei54dv0a4gh85776sfbech2sasnh7.apps.googleusercontent.com",
                        ),
                      );
                      await GoogleSignIn.instance.authenticate().then((
                        val,
                      ) async {
                        String? userId = OneSignal.User.pushSubscription.id;
                        var response = await Dio().post(
                          "https://globee-trading.com/app2026/sql.php",
                          data: FormData.fromMap({
                            "action": "create_social_account",
                            "name": val.displayName,
                            "email": val.email,
                            "avatar_url": val.photoUrl,
                            "player_id": userId,
                          }),
                        );
                        await FlutterSecureStorage().write(
                          key: "user_uid",
                          value: response.data['data']['id'],
                        );
                        await FlutterSecureStorage().write(
                          key: "user_oid",
                          value: response.data['data']['oid'],
                        );
                        FlutterSecureStorage().write(
                          key: 'social_name',
                          value: val.displayName,
                        );
                        FlutterSecureStorage().write(
                          key: 'social_email',
                          value: val.email,
                        );
                        FlutterSecureStorage().write(
                          key: 'social_avatar',
                          value: val.photoUrl,
                        );
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => SplashScreen(),
                          ),
                        );
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                Visibility(
                  visible: Platform.isIOS ? true : false,
                  child: _buildLoginOptionButton(
                    context: context,
                    imageTxt: "assets/images/social/apple.png",
                    isimg: true,
                    title: 'سجل بواسطة أبل',
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PhoneLoginScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 30),

                // Divider
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

                // Email Login Button
                _buildLoginOptionButton(
                  context: context,
                  icon: Iconsax.sms,
                  isimg: false,
                  title: 'التسجيل بالبريد الإلكتروني',
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

                _buildLoginOptionButton(
                  context: context,
                  imageTxt: "assets/images/social/face.png",
                  isimg: true,
                  title: 'سجل بواسطة الفيسبوك',
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PhoneLoginScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 50),

                // Footer
                Text(
                  'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية',
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
    );
  }

  Widget _buildLoginOptionButton({
    required BuildContext context,
    IconData? icon,
    String? imageTxt,
    bool? isimg,
    required String title,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Directionality(
        textDirection: TextDirection.rtl,
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
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
          color: Colors.white,
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
