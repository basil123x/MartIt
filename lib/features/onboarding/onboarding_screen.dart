import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/localization_service.dart';
import '../home/main_navigation_screen.dart';

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

class _OnboardingPalette {
  final Color bg;
  final Color accent;
  final Color logoBg;
  final Color selectedTileBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;
  final Color divider;
  final Color dotInactive;
  final Color radioUnselected;

  const _OnboardingPalette({
    required this.bg,
    required this.accent,
    required this.logoBg,
    required this.selectedTileBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
    required this.divider,
    required this.dotInactive,
    required this.radioUnselected,
  });

  factory _OnboardingPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _OnboardingPalette(
        bg: Color(0xFF0E0E10),
        accent: Color(0xFFC6FF3D),
        logoBg: Color(0xFF1C1C1F),
        selectedTileBg: Color(0xFF1C1C1F),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFA9A9B2),
        textOnPrimary: Color(0xFF0E0E10),
        divider: Color(0xFF2A2A2E),
        dotInactive: Color(0xFF3A3A3E),
        radioUnselected: Color(0xFF3A3A3E),
      );
    }
    return const _OnboardingPalette(
      bg: Color(0xFFFFFFFF),
      accent: Color(0xFF5C33EA),
      logoBg: Color(0xFFEAE5FC),
      selectedTileBg: Color(0xFFEAE5FC),
      textPrimary: Color(0xFF1A1333),
      textSecondary: Color(0xFF6B6B80),
      textOnPrimary: Color(0xFFFFFFFF),
      divider: Color(0xFFC9BFF5),
      dotInactive: Color(0xFFC9BFF5),
      radioUnselected: Color(0xFFC9BFF5),
    );
  }
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
    OnboardingCountry(
      nameAr: 'السعودية',
      nameEn: 'Saudi Arabia',
      simCode: 'SA',
    ),
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

  static const String _defaultCountryCode = 'QA'; // Qatar — always the default

  @override
  void initState() {
    super.initState();
    _selectedLanguage = LocalizationService.instance.currentLanguage;
    // Default pre-selected country: Qatar (not Saudi Arabia).
    // Language changes must never override this unless the user picks another country.
    _selectedCountry = _countries.firstWhere(
      (c) => c.simCode == _defaultCountryCode,
    );
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
    await prefs.setBool('pending_home_tour', true);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _OnboardingPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [_buildLanguagePage(p), _buildCountryPage(p)],
              ),
            ),
            _buildProgressDots(p),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagImage(String simCode, Color fallbackColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        'https://flagcdn.com/w40/${simCode.toLowerCase()}.png',
        width: 36,
        height: 24,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.flag, size: 20, color: fallbackColor),
      ),
    );
  }

  Widget _buildProgressDots(_OnboardingPalette p) {
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
            color: isActive ? p.accent : p.dotInactive,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildSelectionTile({
    required _OnboardingPalette p,
    required bool isSelected,
    required Widget leading,
    required String title,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              decoration: BoxDecoration(
                color: isSelected ? p.selectedTileBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Accent bar on the start edge when selected
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 4,
                    height: 40,
                    margin: const EdgeInsetsDirectional.only(start: 0),
                    decoration: BoxDecoration(
                      color: isSelected ? p.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  leading,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? p.accent : p.textPrimary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? p.accent : p.radioUnselected,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: p.divider,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  Widget _buildLanguagePage(_OnboardingPalette p) {
    final languages = [
      (code: 'en', sim: 'gb', title: 'English'),
      (
        code: 'ar',
        sim: 'sa',
        title: _selectedLanguage == 'ar' ? 'العربية' : 'Arabic',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: p.logoBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(p.accent, BlendMode.srcIn),
                child: Image.asset(
                  'assets/images/app-icon2.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _selectedLanguage == 'ar' ? 'اختر لغتك' : 'Choose your language',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedLanguage == 'ar'
                ? 'يمكنك تغيير اللغة لاحقاً من الإعدادات'
                : 'You can change the language later from settings',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 36),
          ...List.generate(languages.length, (index) {
            final lang = languages[index];
            final isSelected = _selectedLanguage == lang.code;
            return _buildSelectionTile(
              p: p,
              isSelected: isSelected,
              leading: _buildFlagImage(lang.sim, p.textSecondary),
              title: lang.title,
              showDivider: index < languages.length - 1,
              onTap: () async {
                // Only update language — keep whatever country the user has (default Qatar).
                setState(() => _selectedLanguage = lang.code);
                await LocalizationService.instance.changeLanguage(lang.code);
              },
            );
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _goToCountryPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                _selectedLanguage == 'ar' ? 'التالي' : 'Next',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryPage(_OnboardingPalette p) {
    final textDir = _selectedLanguage == 'ar'
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDir,
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
                // Auto-mirrors with Directionality (RTL → points right).
                icon: Icon(Icons.arrow_back, color: p.accent),
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
                    color: p.textPrimary,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedLanguage == 'ar'
                      ? 'سيتم عرض المنتجات المتاحة في دولتك'
                      : 'Products available in your country will be shown',
                  style: TextStyle(fontSize: 14, color: p.textSecondary),
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: _countries.length,
              itemBuilder: (context, index) {
                final country = _countries[index];
                final isSelected = _selectedCountry.simCode == country.simCode;
                return _buildSelectionTile(
                  p: p,
                  isSelected: isSelected,
                  leading: _buildFlagImage(country.simCode, p.textSecondary),
                  title: _selectedLanguage == 'ar'
                      ? country.nameAr
                      : country.nameEn,
                  showDivider: index < _countries.length - 1,
                  onTap: () => setState(() => _selectedCountry = country),
                );
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
                  backgroundColor: p.accent,
                  foregroundColor: p.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
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
}
