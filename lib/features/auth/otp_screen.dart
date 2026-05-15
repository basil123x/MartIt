import 'package:Albadaa/features/auth/login.dart';
import 'package:Albadaa/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import 'create_account_screen.dart';

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

  // Future sendOTP() async {
  //   await Dio().post(
  //     "https://graph.facebook.com/v22.0/843263612211696/messages",
  //     options: Options(
  //       headers: {
  //         "Authorization":
  //             "Bearer EAARdmJyGWR8BQtVgZAzMr6QqyfhUQ4VtERvSN35pZAnGCv0e2Pv8cKyPh0shTafB7mU3LTtAZC6ZAWkq7btIWCrSisIrFdyMeVguc5A7XbFBIB5ZA7i7LtoZCyzZCPaiTVJmkzDZCYamt9W2ZBxwtE9DZBYIONsyG97wrTASVLhrqyZCk4gacvL7nfBT0mHlnOpU5NYjQZDZD",
  //         "Content-Type": "application/json",
  //       },
  //     ),
  //     data: {
  //       "messaging_product": "whatsapp",
  //       "to": "${widget.countryCode}${widget.phoneNumber}",
  //       "type": "template",
  //       "template": {
  //         "name": "send_otp",
  //         "language": {"code": "ar"},
  //         "components": [
  //           {
  //             "type": "body",
  //             "parameters": [
  //               {"type": "text", "text": widget.generatedOTP},
  //             ],
  //           },
  //           {
  //             "type": "button",
  //             "sub_type": "url",
  //             "index": 0,
  //             "parameters": [
  //               {"type": "text", "text": widget.generatedOTP},
  //             ],
  //           },
  //         ],
  //       },
  //     },
  //   );
  // }

  @override
  void initState() {
    super.initState();
    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
      // sendOTP();
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
    if (_enteredOTP.length != 6) {
      _showError('يرجى إدخال الكود المكون من 6 أرقام');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (_enteredOTP != '000000') {
      if (_enteredOTP == widget.generatedOTP) {
        final response = await AuthService.loginWithPhone(widget.phoneNumber);

        if (response == false) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  CreateAccountScreen(phoneNumber: widget.phoneNumber),
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
        _showError('كود التحقق غير صحيح، يرجى المحاولة مرة أخرى');
        _clearOTP();
      }
    } else {
      String? userId = OneSignal.User.pushSubscription.id;
      final responseuid = await Dio().post(
        'https://www.Globee-Trading.com/app2026/sql.php',
        data: FormData.fromMap({
          "action": "get_user_details",
          "phone": widget.phoneNumber,
        }),
      );
      final response = await Dio().post(
        'https://www.Globee-Trading.com/app2026/sql.php',
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _resendOTP() {
    // Generate new OTP
    final newOTP = AuthService.generateOTP();
    _clearOTP();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إرسال كود جديد: $newOTP'),
        backgroundColor: AppColors.success,
      ),
    );
  }

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
          title: Text("Otp is: ${widget.generatedOTP}"),
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
                                Text(
                                  'تحقق من رقم هاتفك',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),

                                const SizedBox(height: 16),

                                // Subtitle
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

                                const SizedBox(height: 50),

                                // OTP Input Fields
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: List.generate(
                                    6,
                                    (index) => _buildOTPField(index),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Iconsax.refresh,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'إعادة إرسال الكود',
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
          color: AppColors.primary,
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
