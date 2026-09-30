import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/app_responsive.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/auth/login.dart';
import 'package:GlobalFarm/features/barcode/barcode_lookup_screen.dart';
import 'package:GlobalFarm/features/cart/shopping_cart_screen.dart';
import 'package:GlobalFarm/features/categories/categories_screen.dart';
import 'package:GlobalFarm/features/home/home_screen.dart';
import 'package:GlobalFarm/features/profile/profile_screen.dart';
import 'package:GlobalFarm/features/wishlist/wishlist_screen.dart';

/// Root shell: Noon/Amazon-style bottom navigation for GlobalFarm.
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  String? _userId;
  bool _loginChecked = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = await AuthService.getCurrentUserId();
    final admin = await AuthService.isAdmin();
    if (!mounted) return;
    setState(() {
      _userId = uid;
      _isAdmin = admin;
      _loginChecked = true;
    });
  }

  Future<void> _onTabSelected(int index) async {
    if (index == 2 || index == 3 || index == 4) {
      final loggedIn = await AuthService.isLoggedIn();
      final uid = await AuthService.getCurrentUserId();
      if (!loggedIn || uid == null || uid.isEmpty) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        await _loadUser();
        final stillLoggedIn = await AuthService.isLoggedIn();
        if (!stillLoggedIn) return;
      } else {
        _userId = uid;
        _isAdmin = await AuthService.isAdmin();
      }
    }

    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  void openCategoriesTab() => _onTabSelected(1);

  @override
  Widget build(BuildContext context) {
    // نستمع للـ LocalizationService حتى يُعاد بناء الـ shell فور تغيير اللغة
    final localization = context.watch<LocalizationService>();
    final ar = localization.currentLanguage == 'ar';

    final Widget middleTab;
    if (_isAdmin) {
      middleTab = const BarcodeLookupScreen();
    } else if (_loginChecked && _userId != null && _userId!.isNotEmpty) {
      middleTab = ShoppingCartScreen(
        userId: _userId!,
        isActive: _currentIndex == 2,
        showBackButton: false,
        onBrowseProducts: () => setState(() => _currentIndex = 0),
      );
    } else {
      middleTab = _LoginPlaceholder(
        message: ar ? 'سجّل دخولك لعرض السلة' : 'Sign in to view your cart',
      );
    }

    final tabs = <Widget>[
      HomeScreen(
        onOpenCategories: openCategoriesTab,
        onOpenCart: () => _onTabSelected(2),
      ),
      const CategoriesScreen(),
      middleTab,
      WishlistScreen(isActive: _currentIndex == 3),
      _loginChecked && _userId != null && _userId!.isNotEmpty
          ? ProfileScreen(
              userId: _userId!,
              onOpenWishlist: () => _onTabSelected(3),
              onOpenHome: () => setState(() => _currentIndex = 0),
            )
          : _LoginPlaceholder(
              message: ar
                  ? 'سجّل دخولك لعرض الملف الشخصي'
                  : 'Sign in to view your profile',
            ),
    ];

    return Directionality(
      textDirection: localization.textDirection,
      child: Scaffold(
        backgroundColor: context.appBackground,
        body: IndexedStack(index: _currentIndex, children: tabs),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDarkMode ? 0.35 : 0.06,
                ),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            backgroundColor: context.appSurface,
            elevation: 0,
            height: AppResponsive.navBarHeight(context),
            indicatorColor: AppColors.primary.withValues(alpha: 0.14),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Iconsax.home),
                selectedIcon:
                    const Icon(Iconsax.home_15, color: AppColors.primary),
                label: ar ? 'الرئيسية' : 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Iconsax.category),
                selectedIcon:
                    const Icon(Iconsax.category5, color: AppColors.primary),
                label: ar ? 'التصنيفات' : 'Categories',
              ),
              NavigationDestination(
                icon: Icon(
                  _isAdmin ? Iconsax.scan_barcode : Iconsax.shopping_cart,
                ),
                selectedIcon: Icon(
                  _isAdmin ? Iconsax.scan_barcode : Iconsax.shopping_cart5,
                  color: AppColors.primary,
                ),
                label: _isAdmin
                    ? (ar ? 'باركود' : 'Barcode')
                    : (ar ? 'السلة' : 'Cart'),
              ),
              NavigationDestination(
                icon: const Icon(Iconsax.heart),
                selectedIcon:
                    const Icon(Iconsax.heart5, color: AppColors.primary),
                label: ar ? 'المفضلة' : 'Wishlist',
              ),
              NavigationDestination(
                icon: const Icon(Iconsax.user),
                selectedIcon: const Icon(
                  Iconsax.profile_circle5,
                  color: AppColors.primary,
                ),
                label: ar ? 'حسابي' : 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginPlaceholder extends StatelessWidget {
  final String message;

  const _LoginPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    final ar = context.watch<LocalizationService>().currentLanguage == 'ar';
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.lock_1, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(Iconsax.login, size: 18),
                label: Text(ar ? 'تسجيل الدخول' : 'Sign in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
