import 'package:GES/features/auth/login.dart';
import 'package:GES/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import 'email_signup_screen.dart';

class EmailOTPScreen extends StatefulWidget {
  final String email;
  final String password;

  const EmailOTPScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<EmailOTPScreen> createState() => _EmailOTPScreenState();
}

class _EmailOTPScreenState extends State<EmailOTPScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String _enteredOTP = '';
  late String _generatedOTP;

  @override
  void initState() {
    super.initState();
    _generatedOTP = AuthService.generateOTP();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
      sendOTPEmail();
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

    _enteredOTP = _controllers.map((controller) => controller.text).join();

    if (_enteredOTP.length == 6) {
      _verifyOTP();
    }
  }

  void _verifyOTP() async {
    if (_enteredOTP.length != 6) {
      _showError('يرجى إدخال الكود المكون من 6 أرقام');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (_enteredOTP == _generatedOTP) {
      try {
        final response = await Dio().post(
          'https://www.Globee-Trading.com/app2026/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
          data: FormData.fromMap({
            "action": "login_with_email",
            "email": widget.email,
            "password": widget.password,
          }),
        );

        print(response);

        if (response.data['success'] == true) {
          String? userId = OneSignal.User.pushSubscription.id;

          final updateResponse = await Dio().post(
            'https://www.Globee-Trading.com/app2026/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
            data: FormData.fromMap({
              "action": "update_fcm_token",
              "email": widget.email,
              "fcm_token": userId,
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
            key: "user_email",
            value: response.data['data']['email'],
          );
          await FlutterSecureStorage().write(
            key: "user_name",
            value: response.data['data']['name'],
          );

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => SplashScreen()),
            );
          }
        } else {
          setState(() {
            _isLoading = false;
          });

          if (response.data['message'] == 'هذا الحساب مسجل بجوجل، يرجى تسجيل الدخول عبر جوجل') {
            _showError(response.data['message']);
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => LoginScreen(),
                ),
              );
            }
          } else {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => EmailSignupScreen(
                    email: widget.email,
                    password: widget.password,
                  ),
                ),
              );
            }
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showError('حدث خطأ أثناء التحقق، يرجى المحاولة مرة أخرى');
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      _showError('كود التحقق غير صحيح، يرجى المحاولة مرة أخرى');
      _clearOTP();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _resendOTP() {
    _generatedOTP = AuthService.generateOTP();
    sendOTPEmail();
    _clearOTP();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إرسال كود جديد: $_generatedOTP'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  sendOTPEmail() async {
    var result = await Dio().post(
      "http://globee-trading.com/app2026/send_email.php?k=${DateTime.now().millisecondsSinceEpoch}",
      data: FormData.fromMap({
        "email": widget.email,
        "otp": _generatedOTP,
        "store_id": "2"
      }),
    );
  }

  // 666402
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
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
                                  child: const Icon(
                                    Iconsax.sms,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),

                                const SizedBox(height: 40),

                                Text(
                                  'تحقق من بريدك الإلكتروني',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: const Color(0xFF6366F1),
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),

                                const SizedBox(height: 16),

                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                    children: [
                                      const TextSpan(
                                        text: 'أدخل الكود المرسل إلى\n',
                                      ),
                                      TextSpan(
                                        text: widget.email,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6366F1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 50),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: List.generate(
                                    6,
                                    (index) => _buildOTPField(index),
                                  ),
                                ),

                                const SizedBox(height: 40),

                                if (_isLoading)
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF6366F1),
                                    ),
                                  ),

                                const SizedBox(height: 40),

                                TextButton(
                                  onPressed: _resendOTP,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Iconsax.refresh,
                                        size: 18,
                                        color: Color(0xFF6366F1),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'إعادة إرسال الكود',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: const Color(0xFF6366F1),
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
                                        'جرب طريقة أخرى',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.primaryLight,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'ألم يصلك الكود ؟',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.black),
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
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF6366F1),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
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
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
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
