import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../auth/login.dart';
import '../chat/conversations_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import 'home_feed_screen.dart';

/// Persistent bottom-tab shell. Main tabs stay in an [IndexedStack] so the
/// nav bar never disappears. Only detail flows (chat thread, settings, etc.)
/// should [Navigator.push] above this screen.
class MainNavigationScreen extends StatefulWidget {
  final String? initialItemId;
  final int initialTabIndex;

  const MainNavigationScreen({
    super.key,
    this.initialItemId,
    this.initialTabIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const Color _navUnselected = Color(0xFFA9A9B2);

  /// IndexedStack indices: 0 Home, 1 Discover, 2 Chat, 3 Profile.
  int _tabIndex = 0;

  /// Nav item indices matching the old feed nav (gap at 2 for +).
  int _navHighlight = 0;

  String? _currentUserId;
  String? _feedItemId;
  int _feedNonce = 0;

  final GlobalKey<HomeFeedScreenState> _feedKey =
      GlobalKey<HomeFeedScreenState>();
  final GlobalKey _tourAddKey = GlobalKey(debugLabel: 'tour_add');

  @override
  void initState() {
    super.initState();
    _feedItemId = widget.initialItemId;
    _tabIndex = _clampTab(widget.initialTabIndex);
    _navHighlight = _tabToNav(_tabIndex);
    _loadCurrentUser();
  }

  int _clampTab(int index) => index.clamp(0, 3);

  /// Map IndexedStack tab → bottom-nav highlight index (skips center +).
  int _tabToNav(int tab) {
    switch (tab) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 3;
      case 3:
        return 4;
      default:
        return 0;
    }
  }

  /// Map bottom-nav index → IndexedStack tab (null = center + action).
  int? _navToTab(int navIndex) {
    switch (navIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return null;
      case 3:
        return 2;
      case 4:
        return 3;
      default:
        return 0;
    }
  }

  Future<void> _loadCurrentUser() async {
    final id = await AuthService.getCurrentUserId();
    if (!mounted) return;
    setState(() => _currentUserId = id);
  }

  Future<bool> _ensureLoggedIn() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) return true;
    final id = await AuthService.getCurrentUserId();
    if (!mounted) return false;
    if (id != null && id.isNotEmpty) {
      setState(() => _currentUserId = id);
      return true;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    final after = await AuthService.getCurrentUserId();
    if (!mounted) return false;
    setState(() => _currentUserId = after);
    return after != null && after.isNotEmpty;
  }

  Future<void> _onNavTap(int navIndex) async {
    if (navIndex == 2) {
      await _feedKey.currentState?.onAddProductPressed();
      return;
    }

    final tab = _navToTab(navIndex);
    if (tab == null) return;

    if (tab == 2 || tab == 3) {
      final ok = await _ensureLoggedIn();
      if (!ok || !mounted) return;
    }

    if (tab == 0 && _navHighlight == 0) {
      // Home re-tap: restock notify badge handling lives on the feed.
      await _feedKey.currentState?.onHomeTabRetapped();
    }

    setState(() {
      _tabIndex = tab;
      _navHighlight = navIndex;
    });
  }

  void _openFeedItem(String itemId) {
    setState(() {
      _tabIndex = 0;
      _navHighlight = 0;
      _feedItemId = itemId;
      _feedNonce++;
    });
  }

  Future<bool> _onWillPop() async {
    if (_tabIndex != 0) {
      setState(() {
        _tabIndex = 0;
        _navHighlight = 0;
      });
      return false;
    }

    final lang = LocalizationService.instance.currentLanguage;
    final exitApp = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(lang == 'ar' ? 'تأكيد الخروج' : 'Confirm Exit'),
            content: Text(
              lang == 'ar'
                  ? 'هل تريد الخروج من التطبيق؟'
                  : 'Do you want to exit the app?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(lang == 'ar' ? 'لا' : 'No'),
              ),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: Text(lang == 'ar' ? 'نعم' : 'Yes'),
              ),
            ],
          ),
        ) ??
        false;
    return exitApp;
  }

  /// Matches the active tab surface so the bar blends with the screen
  /// (black on feed, scaffold color on the other tabs).
  Color get _navBarColor {
    if (_tabIndex == 0) return Colors.black;
    return Theme.of(context).scaffoldBackgroundColor;
  }

  Widget _buildBottomNavBar(String lang) {
    final isAr = lang == 'ar';
    final selected = Theme.of(context).colorScheme.primary;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Extra top space so the + button can sit fully inside the bar widget
    // (Scaffold.bottomNavigationBar clips overflow — don't Positioned(top: -n)).
    const double addSize = 58;
    const double barHeight = 62;
    const double addProtrusion = 28;

    final borderColor = _tabIndex == 0
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.06);

    return SizedBox(
      height: addProtrusion + barHeight + bottomInset,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Bar background + tab icons (flush to bottom).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: _navBarColor,
                border: Border(
                  top: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: SizedBox(
                height: barHeight,
                child: Row(
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Iconsax.home_2,
                      activeIcon: Iconsax.home_15,
                      label: isAr ? 'الرئيسية' : 'Home',
                      selectedColor: selected,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Iconsax.search_normal,
                      activeIcon: Iconsax.search_normal_1,
                      label: isAr ? 'استكشف' : 'Discover',
                      selectedColor: selected,
                    ),
                    const SizedBox(width: 72),
                    _buildNavItem(
                      index: 3,
                      icon: Iconsax.message,
                      activeIcon: Iconsax.message5,
                      label: isAr ? 'المحادثات' : 'Inbox',
                      selectedColor: selected,
                    ),
                    _buildNavItem(
                      index: 4,
                      icon: Iconsax.user,
                      activeIcon: Iconsax.profile_circle5,
                      label: isAr ? 'حسابي' : 'Profile',
                      selectedColor: selected,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Center + sits in the reserved protrusion zone — fully visible.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _buildCenterAddButton(selected, addSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterAddButton(Color brand, double size) {
    final ring = _tabIndex == 0 ? Colors.black : _navBarColor;
    return GestureDetector(
      key: _tourAddKey,
      onTap: () => _onNavTap(2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: brand,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ring, width: 4),
          boxShadow: [
            BoxShadow(
              color: brand.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Iconsax.add,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color selectedColor,
  }) {
    final selected = _navHighlight == index;
    final color = selected ? selectedColor : _navUnselected;
    return Expanded(
      child: InkWell(
        onTap: () => _onNavTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPlaceholder({required String title, required String body}) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.login, size: 64, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await _ensureLoggedIn();
              },
              child: Text(
                LocalizationService.instance.currentLanguage == 'ar'
                    ? 'تسجيل الدخول'
                    : 'Log in',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    final isAr = lang == 'ar';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Directionality(
        textDirection: LocalizationService.instance.textDirection,
        child: Scaffold(
          backgroundColor: _tabIndex == 0
              ? Colors.black
              : Theme.of(context).scaffoldBackgroundColor,
          extendBody: true,
          body: IndexedStack(
            index: _tabIndex,
            children: [
              HomeFeedScreen(
                key: _feedKey,
                initialItemId: _feedItemId,
                showBottomNav: false,
                isTabActive: _tabIndex == 0,
                tourAddKey: _tourAddKey,
                rebuildToken: _feedNonce,
                onSwitchToHomeTab: () {
                  if (_tabIndex == 0) return;
                  setState(() {
                    _tabIndex = 0;
                    _navHighlight = 0;
                  });
                },
              ),
              SearchScreen(
                embeddedInShell: true,
                onItemSelected: _openFeedItem,
              ),
              _currentUserId == null
                  ? _buildLoginPlaceholder(
                      title: isAr ? 'المحادثات' : 'Inbox',
                      body: isAr
                          ? 'سجّل الدخول لعرض محادثاتك'
                          : 'Log in to view your conversations',
                    )
                  : ConversationsScreen(
                      userId: _currentUserId!,
                      embeddedInShell: true,
                    ),
              _currentUserId == null
                  ? _buildLoginPlaceholder(
                      title: isAr ? 'حسابي' : 'Profile',
                      body: isAr
                          ? 'سجّل الدخول لعرض ملفك الشخصي'
                          : 'Log in to view your profile',
                    )
                  : ProfileScreen(
                      userId: _currentUserId!,
                      embeddedInShell: true,
                    ),
            ],
          ),
          bottomNavigationBar: _buildBottomNavBar(lang),
        ),
      ),
    );
  }
}
