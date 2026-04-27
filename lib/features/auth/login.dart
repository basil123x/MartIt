import 'dart:async';
import 'dart:io';
import 'package:MartIt/core/services/google_auth_service.dart';
import 'package:MartIt/features/home/tiktok_feed_screen.dart';
import 'package:MartIt/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
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
  final GoogleAuthService googleAuthService = GoogleAuthService();

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
                      fit: BoxFit.cover,
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
                    
                    final result = await googleAuthService.signInWithGoogle();
                      if (result != null && result['success'] == true) {
                        await FlutterSecureStorage().write(
                          key: "user_uid",
                          value: result['user']['uid'].toString(),
                        );
                        await FlutterSecureStorage().write(
                          key: "user_oid",
                          value: result['user']['oid'].toString(),
                        );
                        FlutterSecureStorage().write(
                          key: 'social_name',
                          value: result['user']['name'].toString(),
                        );
                        FlutterSecureStorage().write(
                          key: 'social_email',
                          value: result['user']['email'].toString(),
                        );
                        FlutterSecureStorage().write(
                          key: 'social_avatar',
                          value: result['user']['avatar'].toString(),
                        );
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => SplashScreen(),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل تسجيل الدخول')),
                        );
                      }
                  },
                ),

                const SizedBox(height: 16),

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

                Opacity(
                  opacity: 0.4,
                  child: Visibility(
                    visible: Platform.isIOS ? true : false,
                    child: _buildLoginOptionButton(
                      context: context,
                      imageTxt: "assets/images/social/apple.png",
                      isimg: true,
                      title: 'سجل بواسطة أبل',
                      subtitle: 'قريباً',
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
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
                    imageTxt: "assets/images/social/face.png",
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
