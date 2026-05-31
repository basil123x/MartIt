import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import 'otp_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class CountryCode {
  final String name;
  final String dialCode;
  final String countryCode; // ISO 3166-1 alpha-2 code (e.g., 'QA', 'SA')
  final int maxLength;

  CountryCode({
    required this.name,
    required this.dialCode,
    required this.countryCode,
    required this.maxLength,
  });
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isValidPhone = false;
  bool _isLoading = false;

  final List<CountryCode> _countries = [
    CountryCode(name: 'قطر', dialCode: '+974', countryCode: 'QA', maxLength: 8),
    CountryCode(name: 'السعودية', dialCode: '+966', countryCode: 'SA', maxLength: 9),
    CountryCode(name: 'الإمارات', dialCode: '+971', countryCode: 'AE', maxLength: 9),
    CountryCode(name: 'الكويت', dialCode: '+965', countryCode: 'KW', maxLength: 8),
    CountryCode(name: 'البحرين', dialCode: '+973', countryCode: 'BH', maxLength: 8),
    CountryCode(name: 'عمان', dialCode: '+968', countryCode: 'OM', maxLength: 8),
    CountryCode(name: 'مصر', dialCode: '+20', countryCode: 'EG', maxLength: 10),
    CountryCode(name: 'الأردن', dialCode: '+962', countryCode: 'JO', maxLength: 9),
    CountryCode(name: 'لبنان', dialCode: '+961', countryCode: 'LB', maxLength: 8),
    CountryCode(name: 'سوريا', dialCode: '+963', countryCode: 'SY', maxLength: 9),
    CountryCode(name: 'العراق', dialCode: '+964', countryCode: 'IQ', maxLength: 10),
    CountryCode(name: 'فلسطين', dialCode: '+970', countryCode: 'PS', maxLength: 9),
    CountryCode(name: 'اليمن', dialCode: '+967', countryCode: 'YE', maxLength: 9),
    CountryCode(name: 'المغرب', dialCode: '+212', countryCode: 'MA', maxLength: 9),
    CountryCode(name: 'الجزائر', dialCode: '+213', countryCode: 'DZ', maxLength: 9),
    CountryCode(name: 'تونس', dialCode: '+216', countryCode: 'TN', maxLength: 8),
    CountryCode(name: 'ليبيا', dialCode: '+218', countryCode: 'LY', maxLength: 10),
    CountryCode(name: 'السودان', dialCode: '+249', countryCode: 'SD', maxLength: 9),
    CountryCode(name: 'موريتانيا', dialCode: '+222', countryCode: 'MR', maxLength: 8),
    CountryCode(name: 'الصومال', dialCode: '+252', countryCode: 'SO', maxLength: 9),
    CountryCode(name: 'جيبوتي', dialCode: '+253', countryCode: 'DJ', maxLength: 8),
    CountryCode(name: 'جزر القمر', dialCode: '+269', countryCode: 'KM', maxLength: 7),
  ];

  late CountryCode _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = _countries[0];
    _phoneController.addListener(_validatePhone);
  }

  void _validatePhone() {
    setState(() {
      String phoneNumber = _phoneController.text;

      switch (_selectedCountry.dialCode) {
        case '+974': // قطر
          _isValidPhone = AuthService.isValidQatarPhone(phoneNumber);
          break;

        case '+966': // السعودية
          _isValidPhone =
              phoneNumber.length == 9 && phoneNumber.startsWith('5');
          break;

        case '+971': // الإمارات
          _isValidPhone =
              phoneNumber.length == 9 &&
              (phoneNumber.startsWith('50') ||
                  phoneNumber.startsWith('52') ||
                  phoneNumber.startsWith('54') ||
                  phoneNumber.startsWith('55') ||
                  phoneNumber.startsWith('56') ||
                  phoneNumber.startsWith('58'));
          break;

        case '+965': // الكويت
          _isValidPhone =
              phoneNumber.length == 8 &&
              (phoneNumber.startsWith('5') ||
                  phoneNumber.startsWith('6') ||
                  phoneNumber.startsWith('9'));
          break;

        case '+973': // البحرين
          _isValidPhone =
              phoneNumber.length == 8 &&
              (phoneNumber.startsWith('3') || phoneNumber.startsWith('6'));
          break;

        case '+968': // عمان
          _isValidPhone =
              phoneNumber.length == 8 &&
              (phoneNumber.startsWith('9') || phoneNumber.startsWith('7'));
          break;

        case '+20': // مصر
          _isValidPhone =
              phoneNumber.length == 10 &&
              (phoneNumber.startsWith('10') ||
                  phoneNumber.startsWith('11') ||
                  phoneNumber.startsWith('12') ||
                  phoneNumber.startsWith('15'));
          break;

        case '+962': // الأردن
          _isValidPhone =
              phoneNumber.length == 9 && phoneNumber.startsWith('7');
          break;

        case '+961': // لبنان
          _isValidPhone =
              phoneNumber.length == 8 &&
              (phoneNumber.startsWith('3') ||
                  phoneNumber.startsWith('70') ||
                  phoneNumber.startsWith('71') ||
                  phoneNumber.startsWith('76') ||
                  phoneNumber.startsWith('78') ||
                  phoneNumber.startsWith('79') ||
                  phoneNumber.startsWith('81'));
          break;

        case '+963': // سوريا
          _isValidPhone =
              phoneNumber.length == 9 && phoneNumber.startsWith('9');
          break;

        case '+964': // العراق
          _isValidPhone =
              phoneNumber.length == 10 && phoneNumber.startsWith('7');
          break;

        case '+970': // فلسطين
          _isValidPhone =
              phoneNumber.length == 9 &&
              (phoneNumber.startsWith('56') || phoneNumber.startsWith('59'));
          break;

        case '+967': // اليمن
          _isValidPhone =
              phoneNumber.length == 9 && phoneNumber.startsWith('7');
          break;

        case '+212': // المغرب
          _isValidPhone =
              phoneNumber.length == 9 &&
              (phoneNumber.startsWith('6') || phoneNumber.startsWith('7'));
          break;

        case '+213': // الجزائر
          _isValidPhone =
              phoneNumber.length == 9 &&
              (phoneNumber.startsWith('5') ||
                  phoneNumber.startsWith('6') ||
                  phoneNumber.startsWith('7'));
          break;

        case '+216': // تونس
          _isValidPhone =
              phoneNumber.length == 8 &&
              (phoneNumber.startsWith('2') ||
                  phoneNumber.startsWith('4') ||
                  phoneNumber.startsWith('5') ||
                  phoneNumber.startsWith('9'));
          break;

        case '+218': // ليبيا
          _isValidPhone =
              phoneNumber.length == 10 && phoneNumber.startsWith('9');
          break;

        case '+249': // السودان
          _isValidPhone =
              phoneNumber.length == 9 && phoneNumber.startsWith('9');
          break;

        case '+222': // موريتانيا
          _isValidPhone = phoneNumber.length == 8;
          break;

        case '+252': // الصومال
          _isValidPhone =
              (phoneNumber.length == 8 || phoneNumber.length == 9) &&
              (phoneNumber.startsWith('6') || phoneNumber.startsWith('7'));
          break;

        case '+253': // جيبوتي
          _isValidPhone =
              phoneNumber.length == 8 && phoneNumber.startsWith('77');
          break;

        case '+269': // جزر القمر
          _isValidPhone = phoneNumber.length == 7;
          break;

        default:
          // للدول الأخرى: التحقق من الطول فقط
          _isValidPhone = phoneNumber.length == _selectedCountry.maxLength;
          break;
      }
    });
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'اختر كود الدولة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      ..._countries.map(
                        (country) => InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCountry = country;
                              _phoneController.clear();
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _selectedCountry.dialCode == country.dialCode
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.lightGrey.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    'https://flagcdn.com/w40/${country.countryCode.toLowerCase()}.png',
                                    width: 36,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Text(country.dialCode, style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        country.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                      Text(
                                        country.dialCode,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectedCountry.dialCode ==
                                    country.dialCode)
                                  Icon(
                                    Iconsax.tick_circle5,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendOTP() async {
    if (!_isValidPhone) return;

    setState(() {
      _isLoading = true;
    });

    final otp = AuthService.generateOTP();

    setState(() {
      _isLoading = false;
    });

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
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
                                // Icon
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primary.withValues(
                                          alpha: 0.7,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Iconsax.mobile,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),

                                const SizedBox(height: 40),

                                Text(
                                  textAlign: TextAlign.center,
                                  'تسجيل الدخول برقم الهاتف',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  'سنرسل لك رمز التحقق عبر رسالة نصية',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),

                                const SizedBox(height: 60),

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
                                    controller: _phoneController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(
                                        _selectedCountry.maxLength,
                                      ),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: '12345678',
                                      hintStyle: TextStyle(
                                        color: AppColors.textHint,
                                        letterSpacing: 2,
                                      ),
                                      prefixIcon: InkWell(
                                        onTap: _showCountryPicker,
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(16),
                                          bottomRight: Radius.circular(16),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(3),
                                                child: Image.network(
                                                  'https://flagcdn.com/w40/${_selectedCountry.countryCode.toLowerCase()}.png',
                                                  width: 30,
                                                  height: 20,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      Text(_selectedCountry.dialCode, style: TextStyle(fontSize: 11)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _selectedCountry.dialCode,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_drop_down,
                                                color: AppColors.primary,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 1,
                                                height: 20,
                                                color: AppColors.lightGrey,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      suffixIcon: Container(
                                        padding: _isValidPhone
                                            ? EdgeInsets.all(12)
                                            : EdgeInsets.all(0),
                                        child: IconButton(
                                          onPressed: () {},
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          splashRadius: 20,
                                          icon: Icon(
                                            _isValidPhone
                                                ? Iconsax.tick_circle5
                                                : Iconsax.close_circle5,
                                            color: _isValidPhone
                                                ? AppColors.success
                                                : AppColors.error,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
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
                                          color: AppColors.primary,
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

                                Text(
                                  'أدخل رقم هاتفك (${_selectedCountry.maxLength} أرقام)',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),

                                const SizedBox(height: 40),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isValidPhone && !_isLoading
                                        ? _sendOTP
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: _isValidPhone ? 8 : 0,
                                      shadowColor: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
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
                                              const Icon(Iconsax.sms, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'إرسال كود التحقق',
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
                            'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية',
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
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
