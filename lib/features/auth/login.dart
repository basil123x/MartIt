import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:MartIt/core/services/apple_auth_service.dart';
import 'package:MartIt/core/services/auth_service.dart';
import 'package:MartIt/core/services/avatar_service.dart';
import 'package:MartIt/core/services/google_auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:MartIt/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_theme.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/theme_extensions.dart';
import 'phone_login_screen.dart';
import 'email_login_screen.dart';
import 'otp_screen.dart';
import '../../core/services/api_config_service.dart';
import '../../core/services/terms_acceptance_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleAuthService googleAuthService = GoogleAuthService();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  bool _isAppleLoading = false;
  bool _isPhoneLoading = false;
  bool _isValidPhone = false;
  bool _termsAccepted = false;
  bool _promptedTerms = false;
  bool _termsRouteOpen = false;
  late CountryCode _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = kPhoneCountries.first;
    _phoneController.addListener(_onPhoneChanged);
    _phoneFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requireTerms(automatic: true);
    });
  }

  Future<bool> _requireTerms({bool automatic = false}) async {
    if (_termsAccepted || await TermsAcceptanceService.hasAccepted()) {
      if (mounted) setState(() => _termsAccepted = true);
      return true;
    }
    if (_termsRouteOpen) return false;
    if (automatic && _promptedTerms) return false;
    _promptedTerms = true;
    _termsRouteOpen = true;
    if (!mounted) return false;
    final accepted = await TermsAcceptanceService.ensureAccepted(context);
    _termsRouteOpen = false;
    if (!mounted) return false;
    setState(() => _termsAccepted = accepted);
    return accepted;
  }

  Future<void> _syncAcceptedTerms() {
    return TermsAcceptanceService.syncCurrentAccount();
  }

  void _onPhoneChanged() {
    final valid = _selectedCountry.isValidPhone(_phoneController.text);
    setState(() => _isValidPhone = valid);
  }

  Future<void> _sendOTP() async {
    if (!await _requireTerms()) return;
    if (!_isValidPhone || _isPhoneLoading) return;
    setState(() => _isPhoneLoading = true);
    final otp = AuthService.generateOTP();
    if (!mounted) return;
    setState(() => _isPhoneLoading = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OTPScreen(
          countryCode: _selectedCountry.dialCode,
          phoneNumber: _phoneController.text,
          generatedOTP: otp,
        ),
      ),
    );
  }

  void _showCountryPicker(bool isAr) {
    final searchController = TextEditingController();
    var filtered = List<CountryCode>.from(kPhoneCountries);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final cs = Theme.of(context).colorScheme;
            final martIt = context.martItColors;

            void applyFilter(String query) {
              final q = query.trim().toLowerCase();
              setSheetState(() {
                if (q.isEmpty) {
                  filtered = List<CountryCode>.from(kPhoneCountries);
                } else {
                  filtered = kPhoneCountries.where((c) {
                    return c.name.toLowerCase().contains(q) ||
                        c.dialCode.contains(q) ||
                        c.countryCode.toLowerCase().contains(q);
                  }).toList();
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: martIt.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'اختر كود الدولة' : 'Choose country code',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        onChanged: applyFilter,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              isAr ? 'ابحث عن دولتك' : 'Search your country',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Iconsax.search_normal_1,
                            color: cs.onSurfaceVariant,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: martIt.fieldBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: martIt.fieldBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: martIt.fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: cs.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                isAr ? 'لا توجد نتائج' : 'No results',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                thickness: 1,
                                color: martIt.divider,
                              ),
                              itemBuilder: (context, index) {
                                final country = filtered[index];
                                final selected = country.dialCode ==
                                    _selectedCountry.dialCode;
                                return Material(
                                  color: selected
                                      ? cs.primaryContainer
                                      : context.appSurface,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedCountry = country;
                                        _phoneController.clear();
                                        _isValidPhone = false;
                                      });
                                      Navigator.pop(sheetContext);
                                    },
                                    child: SizedBox(
                                      height: 64,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Image.network(
                                                'https://flagcdn.com/w40/${country.countryCode.toLowerCase()}.png',
                                                width: 36,
                                                height: 24,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Text(
                                                  country.dialCode,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    country.name,
                                                    style: TextStyle(
                                                      color: cs.onSurface,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    country.dialCode,
                                                    style: TextStyle(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (selected)
                                              Icon(
                                                Iconsax.tick_circle5,
                                                color: cs.primary,
                                                size: 22,
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
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(searchController.dispose);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    if (!await _requireTerms()) return;
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
          ApiConfigService.instance.sqlUrl(),
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

          await _syncAcceptedTerms();
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

            await _syncAcceptedTerms();
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
    if (!await _requireTerms()) return;
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

      await _syncAcceptedTerms();
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
    final isAr = lang == 'ar';
    final cs = Theme.of(context).colorScheme;
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
              icon: Icon(
                Icons.arrow_back_ios,
                color: cs.onSurface,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: context.appSurface,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Image.asset(
                                'assets/images/app-icon2.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppStrings.appName,
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 32,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isAr
                                ? 'مرحباً بك في عالم التسوق الذكي'
                                : 'Welcome to the Smart Shopping World',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 16,
                                      height: 1.4,
                                    ),
                          ),
                          const SizedBox(height: 24),
                          if (!_termsAccepted) _buildTermsGate(),
                          if (!_termsAccepted) const SizedBox(height: 16),
                          _buildPhoneAuthSection(isAr),
                          const SizedBox(height: 28),
                          _buildOrDivider(isAr),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCircleAuthSlot(
                                child: _buildCircleAuthButton(
                                  background: context.appSurface,
                                  borderColor: context.martItColors.fieldBorder,
                                  onTap: _googleSignIn,
                                  child: Image.asset(
                                    'assets/images/social/google.png',
                                    width: 26,
                                    height: 26,
                                  ),
                                ),
                              ),
                              if (Platform.isIOS) ...[
                                const SizedBox(width: 16),
                                _buildCircleAuthSlot(
                                  child: _buildCircleAuthButton(
                                    background: Colors.black,
                                    onTap:
                                        _isAppleLoading ? null : _appleSignIn,
                                    child: _isAppleLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Image.asset(
                                            'assets/images/social/apple.png',
                                            width: 24,
                                            height: 24,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 16),
                              _buildCircleAuthSlot(
                                child: _buildCircleAuthButton(
                                  background: context.appIconPillBg,
                                  onTap: () async {
                                    if (!await _requireTerms()) return;
                                    if (!mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EmailLoginScreen(),
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    Iconsax.sms,
                                    color: cs.primary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          TextButton(
                            onPressed: () => _requireTerms(),
                            child: Text(
                              tr('moderation.eula_title'),
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildTermsGate() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('moderation.eula_must_accept'),
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _requireTerms(),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(tr('moderation.eula_review')),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneAuthSection(bool isAr) {
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;
    final unfocusedBorder = martIt.fieldBorder;
    final borderRadius = BorderRadius.circular(16);
    final hasText = _phoneController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            TextField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendOTP(),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_selectedCountry.maxLength),
              ],
              decoration: InputDecoration(
                filled: true,
                fillColor: martIt.fieldBg,
                hintText: isAr ? 'رقم الجوال' : 'Phone number',
                hintStyle: TextStyle(
                  color: martIt.mutedText,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  letterSpacing: 0,
                ),
                // Reserve trailing space so text never sits under the status icon.
                contentPadding: const EdgeInsetsDirectional.only(
                  start: 12,
                  end: 44,
                  top: 16,
                  bottom: 16,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
                  child: InkWell(
                    onTap: () => _showCountryPicker(isAr),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.network(
                            'https://flagcdn.com/w40/${_selectedCountry.countryCode.toLowerCase()}.png',
                            width: 28,
                            height: 20,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Iconsax.global,
                              size: 18,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedCountry.dialCode,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Iconsax.arrow_down_1,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        Container(
                          margin: const EdgeInsetsDirectional.only(start: 8),
                          width: 1,
                          height: 22,
                          color: unfocusedBorder,
                        ),
                      ],
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: borderRadius,
                  borderSide: BorderSide(color: unfocusedBorder, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: borderRadius,
                  borderSide: BorderSide(color: unfocusedBorder, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: borderRadius,
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
              ),
            ),
            // Absolute slot so error/success icons never shift.
            PositionedDirectional(
              start: null,
              end: 12,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: 22,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: hasText ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: Icon(
                      _isValidPhone
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 22,
                      color: _isValidPhone
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            isAr
                ? 'أدخل رقم هاتفك لاستلام رمز التحقق'
                : 'Enter your phone number to receive a code',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isPhoneLoading
                ? null
                : !_termsAccepted
                    ? () => _requireTerms()
                    : (_isValidPhone ? _sendOTP : null),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              disabledBackgroundColor: cs.primary.withValues(alpha: 0.35),
              foregroundColor: cs.onPrimary,
              disabledForegroundColor: cs.onPrimary.withValues(alpha: 0.7),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: cs.primary.withValues(alpha: 0.35),
            ),
            child: _isPhoneLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: cs.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.sms, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isAr ? 'إرسال رمز التحقق' : 'Send verification code',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrDivider(bool isAr) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final divider = context.appDivider;
    return Row(
      children: [
        Expanded(
          child: Divider(color: divider, thickness: 1, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            isAr ? 'أو' : 'or',
            style: TextStyle(
              color: secondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: divider, thickness: 1, height: 1),
        ),
      ],
    );
  }

  Widget _buildCircleAuthSlot({required Widget child, String? label}) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 6),
          SizedBox(
            height: 14,
            child: label == null
                ? const SizedBox.shrink()
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAuthButton({
    required Color background,
    Color? borderColor,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor ?? Colors.transparent,
              width: borderColor != null ? 1.5 : 0,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
