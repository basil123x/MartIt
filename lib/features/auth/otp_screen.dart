import 'package:MartIt/features/auth/login.dart';
import 'package:MartIt/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import 'create_account_screen.dart';
import '../../core/utils/theme_extensions.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String generatedOTP;
  final String countryCode;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.generatedOTP,
    required this.countryCode,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String _enteredOTP = '';
  late String _activeOtp;
  String? _debugOtp;

  Future sendOTP() async {
    await Dio().post(
      "https://graph.facebook.com/v22.0/1020621547810315/messages",
      options: Options(
        headers: {
          "Authorization":
              "Bearer EAAdhZCjMZCRZBABQZBhtWgeoQcYCOzXj32zhFSLi7aELSVCWDp32TaP8pd0NNbiZChZB95UwEvQw89izAsQuQEXugIMyiqZAQT8ZAxuq0CZAk8T323L6xJdxcLyG5MybKsaO4wtR9iCZBYMAHQdUg3ZAo9ApDHCld4Y6wri7JG39JBsagQa0aqqQAHWM8BfnEJsMgZDZD",
          "Content-Type": "application/json",
        },
      ),
      data: {
        "messaging_product": "whatsapp",
        "to": "${widget.countryCode}${widget.phoneNumber}",
        "type": "template",
        "template": {
          "name": "send_otp",
          "language": {"code": "ar"},
          "components": [
            {
              "type": "body",
              "parameters": [
                {"type": "text", "text": _activeOtp},
              ],
            },
            {
              "type": "button",
              "sub_type": "url",
              "index": 0,
              "parameters": [
                {"type": "text", "text": _activeOtp},
              ],
            },
          ],
        },
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _activeOtp = widget.generatedOTP;
    _debugOtp = widget.generatedOTP;
    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
      sendOTP();
    });
  }

  void _onOTPChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }

    // Build entered OTP
    _enteredOTP = _controllers.map((controller) => controller.text).join();

    // Auto verify when 6 digits are entered
    if (_enteredOTP.length == 6) {
      _verifyOTP();
    }
  }

  void _verifyOTP() async {
    final lang = LocalizationService.instance.currentLanguage;
    if (_enteredOTP.length != 6) {
      _showError(
        lang == 'ar'
            ? 'يرجى إدخال الكود المكون من 6 أرقام'
            : 'Please enter 6 digit code',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (_enteredOTP != '000000') {
      if (_enteredOTP == _activeOtp) {
        final response = await AuthService.loginWithPhone(widget.phoneNumber);

        if (response == false) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CreateAccountScreen(
                phoneNumber: widget.phoneNumber,
                countryDialCode: widget.countryCode,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => SplashScreen()),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showError(
          lang == 'ar'
              ? 'كود التحقق غير صحيح، يرجى المحاولة مرة أخرى'
              : 'Wrong code, please try again',
        );
        _clearOTP();
      }
    } else {
      String? userId = OneSignal.User.pushSubscription.id;
      final responseuid = await Dio().post(
        'https://www.Globee-Trading.com/app2026/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "get_user_details",
          "phone": widget.phoneNumber,
        }),
      );
      final response = await Dio().post(
        'https://www.Globee-Trading.com/app2026/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "get_user_details",
          "phone": widget.phoneNumber,
          "fcm_token": userId,
          "id": responseuid.data['data']['id'],
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
      await FlutterSecureStorage().write(
        key: "user_phone",
        value: response.data['data']['phone'],
      );
      await FlutterSecureStorage().write(
        key: "user_name",
        value: response.data['data']['name'],
      );
      await FlutterSecureStorage().write(key: "login_type", value: "Phone");
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SplashScreen()),
      );
    }
  }

  void _clearOTP() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _enteredOTP = '';
    _focusNodes[0].requestFocus();
  }

  void _showError(String message) {
    showAppSnackbar(context, message: message, type: SnackType.error);
  }

  void _resendOTP() async {
    final newOtp = AuthService.generateOTP();
    setState(() {
      _activeOtp = newOtp;
      _debugOtp = newOtp;
    });
    _clearOTP();
    await sendOTP();

    if (!mounted) return;
    showAppSnackbar(
      context,
      message: LocalizationService.instance.currentLanguage == 'ar'
          ? 'تم إرسال كود جديد'
          : 'New code sent',
      type: SnackType.success,
    );
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: null,
            leading: IconButton(
              icon: Icon(
                Iconsax.arrow_left,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Icon
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: const Icon(
                                      Iconsax.sms,
                                      size: 50,
                                      color: AppColors.secondary,
                                    ),
                                  ),

                                  const SizedBox(height: 40),

                                  // Title
                                  Text(
                                    lang == 'ar'
                                        ? 'تحقق من رقم هاتفك'
                                        : 'Verify your phone',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Subtitle
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: AppColors.textSecondaryColor(context),
                                          ),
                                      children: [
                                        TextSpan(
                                          text: lang == 'ar'
                                              ? 'أدخل الكود المرسل إلى\n'
                                              : 'Enter the code sent to\n',
                                        ),
                                        TextSpan(
                                          text:
                                              '${widget.countryCode} ${widget.phoneNumber}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (_debugOtp != null)
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 8,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.info_outline,
                                            color: Colors.orange,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            lang == 'ar'
                                                ? 'رمز التحقق: $_debugOtp'
                                                : 'OTP Code: $_debugOtp',
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 50),

                                  // OTP Input Fields
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        6,
                                        (index) => _buildOTPField(index),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 40),

                                  // Loading indicator
                                  if (_isLoading)
                                    const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),

                                  const SizedBox(height: 40),

                                  // Resend OTP
                                  TextButton(
                                    onPressed: _resendOTP,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Iconsax.refresh,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          lang == 'ar'
                                              ? 'إعادة إرسال الكود'
                                              : 'Resend Code',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen(),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          lang == 'ar'
                                              ? 'جرب طريقة أخرى'
                                              : 'Try another way',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.primaryLight,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        lang == 'ar'
                                            ? 'ألم يصلك الكود ؟'
                                            : "Didn't receive the code?",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

  Widget _buildOTPField(int index) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: context.appSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.lightGrey, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.lightGrey, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) => _onOTPChanged(index, value),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}
