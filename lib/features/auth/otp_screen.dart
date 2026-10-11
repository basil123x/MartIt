import 'dart:async';

import 'package:MartIt/core/services/otp_local_notification_service.dart';
import 'package:MartIt/features/auth/login.dart';
import 'package:MartIt/features/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/theme_extensions.dart';
import 'create_account_screen.dart';
import '../../core/services/moderation_service.dart';
import '../../core/services/terms_acceptance_service.dart';

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
  static const int _resendSeconds = 60;

  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String _enteredOTP = '';
  late String _activeOtp;
  int _resendRemaining = _resendSeconds;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    // Prefer the OTP generated at navigation time; regenerate if empty.
    _activeOtp = widget.generatedOTP.trim().isNotEmpty
        ? widget.generatedOTP
        : AuthService.generateOTP();

    for (final node in _focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }

    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _focusNodes[0].requestFocus();
      await _deliverOtpNotification(_activeOtp);
    });
  }

  Future<void> _deliverOtpNotification(String otp) async {
    await OtpLocalNotificationService.showOtpNotification(otp: otp);
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendRemaining = _resendSeconds;
    if (mounted) setState(() {});

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendRemaining <= 1) {
        timer.cancel();
        setState(() => _resendRemaining = 0);
      } else {
        setState(() => _resendRemaining -= 1);
      }
    });
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _onOTPChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < 6; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final focusIndex = digits.length.clamp(0, 5);
      _focusNodes[focusIndex].requestFocus();
    } else if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    _enteredOTP = _controllers.map((c) => c.text).join();
    setState(() {});

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

    setState(() => _isLoading = true);

    try {
      final reviewer = await ModerationService.verifyReviewerPhone(
        phone: '${widget.countryCode}${widget.phoneNumber}',
        code: _enteredOTP,
      );
      if (reviewer['success'] == true && reviewer['data'] is Map) {
        final data = Map<String, dynamic>.from(reviewer['data'] as Map);
        await const FlutterSecureStorage().write(
          key: 'user_uid',
          value: data['id']?.toString() ?? '',
        );
        await const FlutterSecureStorage().write(
          key: 'user_oid',
          value: data['oid']?.toString() ?? '',
        );
        await const FlutterSecureStorage().write(
          key: 'user_name',
          value: data['name']?.toString() ?? '',
        );
        await const FlutterSecureStorage().write(
          key: 'user_phone',
          value: data['phone']?.toString() ?? widget.phoneNumber,
        );
        await const FlutterSecureStorage().write(key: 'login_type', value: 'Phone');
        await TermsAcceptanceService.syncCurrentAccount();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => SplashScreen()),
        );
        return;
      }
    } catch (_) {
      // A normal code continues with the local verification below.
    }

    if (_enteredOTP == _activeOtp) {
        final response = await AuthService.loginWithPhone(widget.phoneNumber);

        if (response == false) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CreateAccountScreen(
                phoneNumber: widget.phoneNumber,
                countryDialCode: widget.countryCode,
              ),
            ),
          );
        } else {
          await TermsAcceptanceService.syncCurrentAccount();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => SplashScreen()),
          );
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError(
          lang == 'ar'
              ? 'كود التحقق غير صحيح، يرجى المحاولة مرة أخرى'
              : 'Wrong code, please try again',
        );
        _clearOTP();
      }
  }

  void _clearOTP() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _enteredOTP = '';
    _focusNodes[0].requestFocus();
    setState(() {});
  }

  void _showError(String message) {
    showAppSnackbar(context, message: message, type: SnackType.error);
  }

  Future<void> _resendOTP() async {
    if (_resendRemaining > 0 || _isLoading) return;

    final newOtp = AuthService.generateOTP();
    setState(() => _activeOtp = newOtp);
    _clearOTP();
    _startResendTimer();
    await _deliverOtpNotification(newOtp);

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
    final isAr = lang == 'ar';
    final canConfirm = _enteredOTP.length == 6 && !_isLoading;
    final canResend = _resendRemaining == 0 && !_isLoading;
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;

    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: cs.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 16,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: context.appIconPillBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Iconsax.shield_tick,
                                size: 42,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              isAr
                                  ? 'تحقق من رقم هاتفك'
                                  : 'Verify your phone',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isAr
                                  ? 'أدخل الكود المرسل إلى'
                                  : 'Enter the code sent to',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${widget.countryCode} ${widget.phoneNumber}',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                children: List.generate(6, (index) {
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: index == 0 ? 0 : 5,
                                        right: index == 5 ? 0 : 5,
                                      ),
                                      child: _buildOTPField(index),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (_resendRemaining > 0)
                              Text(
                                isAr
                                    ? 'إعادة الإرسال خلال ${_formatCountdown(_resendRemaining)}'
                                    : 'Resend in ${_formatCountdown(_resendRemaining)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else
                              TextButton(
                                onPressed: canResend ? _resendOTP : null,
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Iconsax.refresh, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      isAr
                                          ? 'إعادة إرسال الكود'
                                          : 'Resend Code',
                                      style: TextStyle(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  isAr
                                      ? 'ألم يصلك الكود؟'
                                      : "Didn't receive the code?",
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
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
                                    isAr
                                        ? 'جرب طريقة أخرى'
                                        : 'Try another way',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 36),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: canConfirm ? _verifyOTP : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  disabledBackgroundColor: martIt.divider,
                                  foregroundColor: cs.onPrimary,
                                  disabledForegroundColor: martIt.mutedText,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 17,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: cs.onPrimary,
                                        ),
                                      )
                                    : Text(
                                        isAr ? 'تأكيد' : 'Confirm',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: canConfirm
                                              ? cs.onPrimary
                                              : martIt.mutedText,
                                        ),
                                      ),
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
    final focused = _focusNodes[index].hasFocus;
    final filled = _controllers[index].text.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;

    Color borderColor;
    Color fillColor;
    double borderWidth;
    List<BoxShadow>? shadows;

    if (focused) {
      borderColor = cs.primary;
      fillColor = context.appSurface;
      borderWidth = 2;
      shadows = [
        BoxShadow(
          color: cs.primary.withValues(alpha: 0.14),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (filled) {
      borderColor = cs.primary;
      fillColor = cs.primaryContainer;
      borderWidth = 1.5;
      shadows = null;
    } else {
      borderColor = martIt.fieldBorder;
      fillColor = martIt.fieldBg;
      borderWidth = 1.2;
      shadows = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 56,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: cs.onSurface,
            height: 1.2,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          onChanged: (value) => _onOTPChanged(index, value),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}
