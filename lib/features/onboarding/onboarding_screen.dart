import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/localization_service.dart';
import '../home/tiktok_feed_screen.dart';
import '../../core/utils/theme_extensions.dart';

class OnboardingCountry {
  final String nameAr;
  final String nameEn;
  final String simCode;

  const OnboardingCountry({
    required this.nameAr,
    required this.nameEn,
    required this.simCode,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  String _selectedLanguage = 'ar';
  late OnboardingCountry _selectedCountry;
  int _currentPage = 0;

  static const List<OnboardingCountry> _countries = [
    OnboardingCountry(nameAr: 'السعودية', nameEn: 'Saudi Arabia', simCode: 'SA'),
    OnboardingCountry(nameAr: 'الإمارات', nameEn: 'UAE', simCode: 'AE'),
    OnboardingCountry(nameAr: 'قطر', nameEn: 'Qatar', simCode: 'QA'),
    OnboardingCountry(nameAr: 'الكويت', nameEn: 'Kuwait', simCode: 'KW'),
    OnboardingCountry(nameAr: 'البحرين', nameEn: 'Bahrain', simCode: 'BH'),
    OnboardingCountry(nameAr: 'عُمان', nameEn: 'Oman', simCode: 'OM'),
    OnboardingCountry(nameAr: 'مصر', nameEn: 'Egypt', simCode: 'EG'),
    OnboardingCountry(nameAr: 'الأردن', nameEn: 'Jordan', simCode: 'JO'),
    OnboardingCountry(nameAr: 'لبنان', nameEn: 'Lebanon', simCode: 'LB'),
    OnboardingCountry(nameAr: 'العراق', nameEn: 'Iraq', simCode: 'IQ'),
    OnboardingCountry(nameAr: 'سوريا', nameEn: 'Syria', simCode: 'SY'),
    OnboardingCountry(nameAr: 'اليمن', nameEn: 'Yemen', simCode: 'YE'),
    OnboardingCountry(nameAr: 'ليبيا', nameEn: 'Libya', simCode: 'LY'),
    OnboardingCountry(nameAr: 'تونس', nameEn: 'Tunisia', simCode: 'TN'),
    OnboardingCountry(nameAr: 'الجزائر', nameEn: 'Algeria', simCode: 'DZ'),
    OnboardingCountry(nameAr: 'المغرب', nameEn: 'Morocco', simCode: 'MA'),
    OnboardingCountry(nameAr: 'السودان', nameEn: 'Sudan', simCode: 'SD'),
    OnboardingCountry(nameAr: 'فلسطين', nameEn: 'Palestine', simCode: 'PS'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = LocalizationService.instance.currentLanguage;

    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final countryCode = (deviceLocale.countryCode ?? 'QA').toUpperCase();
    final matchedCountry = _countries.firstWhere(
      (c) => c.simCode == countryCode,
      orElse: () => _countries.firstWhere((c) => c.simCode == 'QA'),
    );
    _selectedCountry = matchedCountry;

    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToCountryPage() async {
    await LocalizationService.instance.changeLanguage(_selectedLanguage);
    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_country', _selectedCountry.simCode);
    await prefs.setBool('onboarding_done', true);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TikTokFeedScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appSurface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildLanguagePage(),
                  _buildCountryPage(),
                ],
              ),
            ),
            _buildProgressDots(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagImage(String simCode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        'https://flagcdn.com/w40/${simCode.toLowerCase()}.png',
        width: 36,
        height: 24,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.flag, size: 20, color: Colors.grey),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildLanguagePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/app-icon2.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _selectedLanguage == 'ar' ? 'اختر لغتك' : 'Choose your language',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedLanguage == 'ar'
                ? 'يمكنك تغيير اللغة لاحقاً من الإعدادات'
                : 'You can change the language later from settings',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: _buildLanguageCard(
                  languageCode: 'en',
                  simCode: 'gb',
                  title: 'English',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLanguageCard(
                  languageCode: 'ar',
                  simCode: 'sa',
                  title: _selectedLanguage == 'ar' ? 'العربية' : 'Arabic',
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _goToCountryPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: Text(
                _selectedLanguage == 'ar' ? 'التالي' : 'Next',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required String languageCode,
    required String simCode,
    required String title,
  }) {
    final isSelected = _selectedLanguage == languageCode;

    return GestureDetector(
      onTap: () async {
        setState(() => _selectedLanguage = languageCode);
        await LocalizationService.instance.changeLanguage(languageCode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFlagImage(simCode),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryPage() {
    return Directionality(
      textDirection:
          _selectedLanguage == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: () => _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                ),
                icon: Icon(
                  _selectedLanguage == 'ar'
                      ? Icons.arrow_forward_ios
                      : Icons.arrow_back_ios,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _selectedLanguage == 'ar'
                      ? 'اختر دولتك'
                      : 'Choose your country',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                  textAlign:
                      _selectedLanguage == 'ar' ? TextAlign.right : TextAlign.left,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedLanguage == 'ar'
                      ? 'سيتم عرض المنتجات المتاحة في دولتك'
                      : 'Products available in your country will be shown',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign:
                      _selectedLanguage == 'ar' ? TextAlign.right : TextAlign.left,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.35,
              ),
              itemCount: _countries.length,
              itemBuilder: (context, index) {
                final country = _countries[index];
                return _buildCountryCard(country);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _finishOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  _selectedLanguage == 'ar' ? 'ابدأ التسوق' : 'Start Shopping',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryCard(OnboardingCountry country) {
    final isSelected = _selectedCountry.simCode == country.simCode;

    return GestureDetector(
      onTap: () => setState(() => _selectedCountry = country),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFlagImage(country.simCode),
            const SizedBox(height: 8),
            Text(
              _selectedLanguage == 'ar' ? country.nameAr : country.nameEn,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : context.appTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
