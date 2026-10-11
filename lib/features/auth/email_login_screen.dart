import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import 'email_otp_screen.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/services/terms_acceptance_service.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isValidEmail = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _passwordStrength = '';
  Color _passwordStrengthColor = AppColors.error;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_checkPasswordStrength);
  }

  void _validateEmail() {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final isValid = emailRegex.hasMatch(_emailController.text);
    if (_isValidEmail != isValid) {
      setState(() {
        _isValidEmail = isValid;
      });
    }
  }

  void _checkPasswordStrength() {
    final lang = LocalizationService.instance.currentLanguage;
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
      });
      return;
    }

    int strength = 0;

    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    setState(() {
      if (strength <= 2) {
        _passwordStrength = lang == 'ar' ? 'ضعيفة' : 'Weak';
        _passwordStrengthColor = AppColors.error;
      } else if (strength <= 4) {
        _passwordStrength = lang == 'ar' ? 'متوسطة' : 'Medium';
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrength = lang == 'ar' ? 'قوية' : 'Strong';
        _passwordStrengthColor = AppColors.success;
      }
    });
  }

  bool _isPasswordStrong() {
    final password = _passwordController.text;
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  void _login() async {
    final lang = LocalizationService.instance.currentLanguage;
    if (!await TermsAcceptanceService.ensureAccepted(context)) return;
    if (!mounted) return;

    if (!_isValidEmail) {
      _showError(lang == 'ar'
          ? 'يرجى إدخال بريد إلكتروني صحيح'
          : 'Please enter a valid email');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError(
        lang == 'ar' ? 'يرجى إدخال كلمة المرور' : 'Please enter your password',
      );
      return;
    }

    if (!_isPasswordStrong()) {
      _showError(
        lang == 'ar'
            ? 'كلمة المرور يجب أن تحتوي على 8 أحرف على الأقل، حرف كبير، حرف صغير، ورقم'
            : 'Password must be at least 8 characters with uppercase, lowercase, and a number',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Dio().post(
        "${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
        data: FormData.fromMap({
          "action": "login_with_email",
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      if (!mounted) return;

      final data = response.data;
      final success = data["success"] == true;
      final message = data["message"]?.toString() ?? "";

      if (success) {
        _navigateToOtp();
        return;
      }

      if (message == "المستخدم غير موجود") {
        _navigateToOtp();
        return;
      }

      if (message == "كلمة المرور غير صحيحة") {
        _showError(
          lang == 'ar' ? 'كلمة المرور غير صحيحة' : 'Incorrect password',
        );
        return;
      }

      if (message.contains("جوجل")) {
        _showError(
          lang == 'ar'
              ? 'هذا الحساب مسجل بجوجل، يرجى تسجيل الدخول عبر جوجل'
              : 'This account is registered with Google, please sign in with Google',
        );
        return;
      }

      _showError(
        message.isNotEmpty
            ? message
            : (lang == 'ar'
                ? 'حدث خطأ، يرجى المحاولة مرة أخرى'
                : 'An error occurred, please try again'),
      );
    } catch (e) {
      if (mounted) {
        _showError(
          lang == 'ar'
              ? 'حدث خطأ في الاتصال، يرجى المحاولة مرة أخرى'
              : 'Connection error, please try again',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToOtp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailOTPScreen(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      ),
    );
  }

  void _showError(String message) {
    showAppSnackbar(context, message: message, type: SnackType.error);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: context.appSurface,
          appBar: AppBar(
            backgroundColor: context.appSurface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF8B5CF6),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF6366F1,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Iconsax.sms,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),

                                  const SizedBox(height: 40),

                                  Text(
                                    lang == 'ar'
                                        ? 'تسجيل الدخول بالبريد الإلكتروني'
                                        : 'Email Login',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: const Color(0xFF6366F1),
                                          fontWeight: FontWeight.bold,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    lang == 'ar'
                                        ? 'أدخل بريدك الإلكتروني وكلمة المرور'
                                        : 'Enter your email and password',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondaryColor(context),
                                        ),
                                  ),

                                  const SizedBox(height: 50),

                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        hintText: 'example@email.com',
                                        hintStyle: TextStyle(
                                          color: AppColors.textHint,
                                        ),
                                        prefixIcon: Icon(
                                          Iconsax.sms,
                                          color: AppColors.primary,
                                        ),
                                        suffixIcon:
                                            _emailController.text.isNotEmpty
                                            ? Icon(
                                                _isValidEmail
                                                    ? Iconsax.tick_circle5
                                                    : Iconsax.close_circle5,
                                                color: _isValidEmail
                                                    ? AppColors.success
                                                    : AppColors.error,
                                              )
                                            : null,
                                        filled: true,
                                        fillColor: context.appSurface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: AppColors.lightGrey,
                                            width: 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: AppColors.lightGrey,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: const Color(0xFF6366F1),
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 20,
                                            ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  if (_passwordController.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Text(
                                            lang == 'ar'
                                                ? 'قوة كلمة المرور: '
                                                : 'Password strength: ',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.textSecondaryColor(context),
                                                ),
                                          ),
                                          Text(
                                            _passwordStrength,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: _passwordStrengthColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 16),

                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _passwordController,
                                      obscureText: !_isPasswordVisible,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        hintText: lang == 'ar'
                                            ? 'كلمة المرور'
                                            : 'Password',
                                        hintStyle: TextStyle(
                                          color: AppColors.textHint,
                                        ),
                                        prefixIcon: Icon(
                                          Iconsax.lock,
                                          color: AppColors.primary,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Iconsax.eye
                                                : Iconsax.eye_slash,
                                            color: AppColors.textSecondaryColor(context),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordVisible =
                                                  !_isPasswordVisible;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: context.appSurface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: AppColors.lightGrey,
                                            width: 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: AppColors.lightGrey,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: const Color(0xFF6366F1),
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 20,
                                            ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 30),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isValidEmail &&
                                              _passwordController
                                                  .text
                                                  .isNotEmpty &&
                                              !_isLoading
                                          ? _login
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation:
                                            _isValidEmail &&
                                                _passwordController
                                                    .text
                                                    .isNotEmpty
                                            ? 8
                                            : 0,
                                        shadowColor: const Color(
                                          0xFF6366F1,
                                        ).withValues(alpha: 0.3),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                      Colors.white,
                                                    ),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Iconsax.login,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  lang == 'ar'
                                                      ? 'تسجيل الدخول'
                                                      : 'Login',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            Text(
                              lang == 'ar'
                                  ? 'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية'
                                  : 'By continuing, you agree to our Terms and Privacy Policy',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
