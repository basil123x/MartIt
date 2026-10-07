import 'package:MartIt/features/update/update_screen.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/api_config_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/store_update_service.dart';
import '../home/main_navigation_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _sloganController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _sloganAnimation;

  String _appVersion = '';
  int? _patchNumber;

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final updater = ShorebirdUpdater();
    final patch = await updater.readCurrentPatch();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
        _patchNumber = patch?.number;
      });
    }
  }

  Future<void> _checkStoreUpdate() async {
    await ApiConfigService.instance.refreshFromRemote();
    if (!mounted) return;
    final requirement = await StoreUpdateService.instance.check();
    if (!mounted || requirement == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ForceUpdateScreen(
          message: requirement.message,
          storeUrl: requirement.storeUrl,
          currentVersion: requirement.currentVersion,
          latestVersion: requirement.latestVersion,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
    _initializeAnimations();
    _boot();
  }

  Future<void> _boot() async {
    await _checkStoreUpdate();
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    _navigateToHome();
  }

  void _initializeAnimations() {
    // Logo Animation Controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Text Animation Controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Slogan Animation Controller
    _sloganController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Logo Scale Animation
    _logoAnimation = Tween<double>(begin: 0.0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Text Fade Animation
    _textAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    // Slide Animation
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    // Slogan Fade Animation
    _sloganAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _sloganController, curve: Curves.easeIn));

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _textController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _sloganController.forward();
    });
  }

  void _navigateToHome() {
    Future.delayed(AppConstants.splashDuration, () async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;
      if (!onboardingDone) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Light: purple brand / Dark: neon lime on near-black (from AppTheme)
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final logoBg = isDark ? cs.surface : cs.primaryContainer;
    final accent = cs.primary;
    final tagline = cs.onSurfaceVariant;
    final slogan = isDark ? cs.onSurfaceVariant : cs.secondary;
    final version = cs.onSurfaceVariant.withValues(alpha: 0.7);

    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: bg,
        body: Container(
          color: bg,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _logoAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _logoAnimation.value,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: logoBg,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Padding(
                                    padding: const EdgeInsets.all(30),
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        accent,
                                        BlendMode.srcIn,
                                      ),
                                      child: Image.asset(
                                        "assets/images/Logo-trans.png",
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 30),

                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _textAnimation,
                            child: Column(
                              children: [
                                Text(
                                  AppStrings.appName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tr('splash.tagline_ar'),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: tagline,
                                        fontWeight: FontWeight.w300,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        FadeTransition(
                          opacity: _sloganAnimation,
                          child: Text(
                            tr('splash.tagline_en'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: slogan,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  fontSize: 16,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _textAnimation,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _textAnimation,
                        child: Text(
                          _appVersion.isNotEmpty
                              ? '$_appVersion v'
                              : '${AppConstants.appVersion} v',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: version),
                        ),
                      ),
                      FadeTransition(
                        opacity: _sloganAnimation,
                        child: Column(
                          children: [
                            if (_patchNumber != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Patch: #$_patchNumber',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: version,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                            ],
                          ],
                        ),
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
  }
}
