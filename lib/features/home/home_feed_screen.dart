import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:MartIt/core/services/onesignal_service.dart';
import 'package:MartIt/core/services/onesignal_service_web.dart';
import 'package:MartIt/features/add_product/media_picker_sheet.dart';
import 'package:MartIt/features/add_product/add_product_screen.dart';
import 'package:MartIt/features/auth/login.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/models/item_model.dart';
import '../../core/widgets/smart_avatar_widget.dart';
import '../../core/widgets/media_viewer_widget.dart';
import '../../core/widgets/item_thumbnail_widget.dart';
import '../../core/widgets/home_tour_overlay.dart';
import '../../core/widgets/uploading_media_frame.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/utils/item_media_url_util.dart';
import '../../core/demo/demo_cars_feed.dart';
import '../product/product_detail_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';
import '../comments/comments_modal.dart';
import '../camera/camera_screen.dart';
import '../cart/cart_screen.dart';
import '../../core/models/cart_model.dart';
import '../chat/conversations_screen.dart';
import '../orders/my_orders_screen.dart';
import '../orders/customer_orders_screen.dart';
import 'package:http/http.dart' as http;
import '../../core/services/api_config_service.dart';

class HomeFeedScreen extends StatefulWidget {
  final String? initialItemId;

  /// When false, this screen is embedded inside [MainNavigationScreen]
  /// and must not render its own bottom nav / exit dialog.
  final bool showBottomNav;

  /// Whether this tab is currently visible in the shell IndexedStack.
  final bool isTabActive;

  /// Shared key for the center "+" control when hosted by the shell.
  final GlobalKey? tourAddKey;

  /// Bumped by the shell to reopen the feed on a specific item (e.g. search).
  final int rebuildToken;

  /// Ask the shell to show the Home tab (e.g. after publishing a product).
  final VoidCallback? onSwitchToHomeTab;

  const HomeFeedScreen({
    super.key,
    this.initialItemId,
    this.showBottomNav = true,
    this.isTabActive = true,
    this.tourAddKey,
    this.rebuildToken = 0,
    this.onSwitchToHomeTab,
  });

  @override
  State<HomeFeedScreen> createState() => HomeFeedScreenState();
}

class HomeFeedScreenState extends State<HomeFeedScreen>
    with TickerProviderStateMixin {
  static const String _prefViewMode = 'view_mode';
  static const String _viewModeTiktok = 'tiktok';
  static const String _viewModeGrid = 'grid';

  String get _lang => LocalizationService.instance.currentLanguage;

  final PageController _pageController = PageController();
  final ScrollController _gridScrollController = ScrollController();
  int _currentIndex = 0;
  DateTime? _itemViewStartTime;
  bool _isLoggedIn = false;
  List<ItemModel> _items = [];
  bool _isLoading = false;
  bool _hasError = false;
  int _currentPage = 0;
  String? _currentItemId;
  String? _currentUserId;
  List<String> _categories = [];
  String?
  _selectedCategory; // ✅ الفلتر الحالي - null = الكل، غير null = تصنيف محدد
  bool _isLoadingCategories = false;
  String? _currentStoreId; // ✅ المتجر الحالي للمنتج المعروض
  String _viewMode = _viewModeTiktok;
  bool _showScrollToTop = false;
  final Map<String, int> _cartQuantities = {};

  /// When a search/open request arrives while a feed load is in flight.
  String? _pendingPinnedItemId;
  Set<String> _notifySubscribed = {};
  bool _showHeartAnimation = false;
  bool _heartIsLiked = true;
  AnimationController? _heartAnimController;
  Animation<double>? _heartScaleAnim;
  Animation<double>? _heartOpacityAnim;
  Color _heartColor = Colors.red;

  // Brand palette (feed chrome)
  static const Color _brandPrimary = Color(0xFF5C33EA);
  static const Color _navUnselected = Color(0xFFA9A9B2);

  int _bottomNavIndex = 0;

  // Interactive home tour (after language/country onboarding)
  bool _showHomeTour = false;
  final GlobalKey _localTourAddKey = GlobalKey(debugLabel: 'tour_add');
  GlobalKey get _tourAddKey => widget.tourAddKey ?? _localTourAddKey;
  final GlobalKey _tourSellerKey = GlobalKey(debugLabel: 'tour_seller');
  final GlobalKey _tourLikeKey = GlobalKey(debugLabel: 'tour_like');
  final GlobalKey _tourCommentKey = GlobalKey(debugLabel: 'tour_comment');
  final GlobalKey _tourShareKey = GlobalKey(debugLabel: 'tour_share');
  final GlobalKey _tourCartKey = GlobalKey(debugLabel: 'tour_cart');
  final GlobalKey _tourInfoKey = GlobalKey(debugLabel: 'tour_info');
  final GlobalKey _tourSwipeKey = GlobalKey(debugLabel: 'tour_swipe');

  Future<String> getUserCountry() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Qatar'; // default
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // ✅ low بدل high أسرع
        timeLimit: Duration(seconds: 5), // ✅ timeout
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      return placemarks.first.country ?? 'Unknown';
    } catch (e) {
      return 'Qatar'; // ✅ default بدل Unknown
    }
  }

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    _checkLoginStatus();
    _gridScrollController.addListener(_onGridScroll);

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heartScaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
        ]).animate(
          CurvedAnimation(parent: _heartAnimController!, curve: Curves.easeOut),
        );

    _heartOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_heartAnimController!);

    _heartAnimController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeartAnimation = false);
        _heartAnimController!.reset();
      }
    });
  }

  void _triggerHeartAnimation(bool isLiking) {
    _heartIsLiked = isLiking;

    if (isLiking) {
      setState(() {
        _showHeartAnimation = true;
        _heartColor = Colors.red;
      });
      _heartAnimController!.forward(from: 0);
    } else {
      setState(() {
        _showHeartAnimation = true;
        _heartColor = Colors.red;
      });
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => _heartColor = Colors.white);
      });
      _heartAnimController!.forward(from: 0);
    }
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefViewMode) ?? _viewModeTiktok;
    if (!mounted) return;
    setState(() {
      _viewMode = saved == _viewModeGrid ? _viewModeGrid : _viewModeTiktok;
    });
  }

  Future<void> _setViewMode(String mode) async {
    if (_viewMode == mode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefViewMode, mode);
    if (!mounted) return;
    setState(() {
      _viewMode = mode;
      if (mode == _viewModeTiktok) {
        _showScrollToTop = false;
      }
    });
  }

  bool get _isTikTokMode => _viewMode == _viewModeTiktok;

  void _onGridScroll() {
    if (_isTikTokMode || !_gridScrollController.hasClients) return;

    final offset = _gridScrollController.offset;
    final showScrollToTop = offset > 300;
    if (showScrollToTop != _showScrollToTop) {
      setState(() => _showScrollToTop = showScrollToTop);
    }

    if (_isLoading || _items.isEmpty) return;

    final position = _gridScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadItems(
        uid: _currentUserId,
        initiItem: '',
        category: _selectedCategory,
      );
    }
  }

  void _scrollGridToTop() {
    if (!_gridScrollController.hasClients) return;
    _gridScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  double _gridHeaderHeight(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return statusBarHeight + 126;
  }

  int _gridCartQuantity(ItemModel item) {
    return _cartQuantities[item.id] ?? item.interactions.cartQuantity;
  }

  void _syncCartQuantitiesFromItems(Iterable<ItemModel> items) {
    for (final item in items) {
      final fromItem = item.interactions.cartQuantity;
      final local = _cartQuantities[item.id] ?? 0;
      // Feed payloads often omit / zero cart qty for items not in the current
      // page. Don't let that wipe the floating-cart badge before a full
      // cart refresh runs.
      if (fromItem > 0 || local == 0) {
        _cartQuantities[item.id] = fromItem;
      } else {
        item.interactions.cartQuantity = local;
      }
    }
  }

  Future<String?> _requireLoginForGridCart(ItemModel item) async {
    if (!_isLoggedIn) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
      return null;
    }

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      if (!mounted) return null;
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'يجب تسجيل الدخول أولاً'
            : 'Please login first',
        type: SnackType.error,
      );
      return null;
    }

    if (currentUserId == item.seller.id) {
      if (!mounted) return null;
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'لا يمكنك إضافة منتجك إلى السلة'
            : 'Cannot add your own product to cart',
        type: SnackType.warning,
      );
      return null;
    }

    return currentUserId;
  }

  void _setGridCartQuantity(String itemId, int quantity) {
    setState(() {
      _cartQuantities[itemId] = quantity;
      final itemIndex = _items.indexWhere((i) => i.id == itemId);
      if (itemIndex != -1) {
        _items[itemIndex].interactions.cartQuantity = quantity;
      }
    });
  }

  int get _totalCartCount =>
      _cartQuantities.values.fold<int>(0, (sum, qty) => sum + qty);

  /// Apply a full cart snapshot (itemId → qty) from [CartScreen] / API.
  void _applyCartSnapshot(Map<String, int> snapshot) {
    setState(() {
      final previouslyInCart = _cartQuantities.entries
          .where((e) => e.value > 0)
          .map((e) => e.key)
          .toSet();

      for (final id in previouslyInCart) {
        if (!snapshot.containsKey(id)) {
          _cartQuantities[id] = 0;
          final itemIndex = _items.indexWhere((i) => i.id == id);
          if (itemIndex != -1) {
            _items[itemIndex].interactions.cartQuantity = 0;
          }
        }
      }

      snapshot.forEach((id, qty) {
        _cartQuantities[id] = qty;
        final itemIndex = _items.indexWhere((i) => i.id == id);
        if (itemIndex != -1) {
          _items[itemIndex].interactions.cartQuantity = qty;
        }
      });
    });
  }

  Future<void> _refreshCartQuantitiesFromServer() async {
    final userId = _currentUserId ?? await AuthService.getCurrentUserId();
    if (userId == null || !mounted) return;

    try {
      final result = await ApiService.getCartItems(userId: userId);
      if (!mounted || result['success'] != true) return;

      final List<dynamic> data = result['data'] ?? [];
      final snapshot = <String, int>{};
      for (final raw in data) {
        final cartItem = CartItemModel.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        snapshot[cartItem.item.id] = cartItem.cartQuantity;
      }
      _applyCartSnapshot(snapshot);
    } catch (_) {
      // Badge stays on local map if refresh fails.
    }
  }

  Future<void> _openCartScreen() async {
    if (!_isLoggedIn) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
      return;
    }

    final currentUserId =
        _currentUserId ?? await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'يجب تسجيل الدخول أولاً'
            : 'Please login first',
        type: SnackType.error,
      );
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          userId: currentUserId,
          onCartUpdated: _applyCartSnapshot,
        ),
      ),
    );
    if (mounted) await _refreshCartQuantitiesFromServer();
  }

  Future<void> _onGridCartAdd(ItemModel item) async {
    final userId = await _requireLoginForGridCart(item);
    if (userId == null) return;

    final current = _gridCartQuantity(item);
    if (item.quantity > 0 && current >= item.quantity) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'الكمية المتاحة: ${item.quantity} فقط'
            : 'Available quantity: ${item.quantity}',
        type: SnackType.warning,
      );
      return;
    }

    final previous = current;
    _setGridCartQuantity(item.id, current + 1);

    try {
      if (previous == 0) {
        ApiService.trackInteraction(userId, item.id, 'cart');
      }
      await ApiService.addToCart(itemId: item.id, userId: userId, quantity: 1);
    } catch (e) {
      if (!mounted) return;
      _setGridCartQuantity(item.id, previous);
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'حدث خطأ أثناء الإضافة إلى السلة'
            : 'Error adding to cart',
        type: SnackType.error,
      );
    }
  }

  Future<void> _onGridCartRemove(ItemModel item) async {
    final userId = await _requireLoginForGridCart(item);
    if (userId == null) return;

    final current = _gridCartQuantity(item);
    if (current <= 0) return;

    final previous = current;
    _setGridCartQuantity(item.id, current - 1);

    try {
      final result = await ApiService.removeFromCart(
        itemId: item.id,
        userId: userId,
      );
      if (result['success'] == true && result['quantity'] != null) {
        final serverQty = result['quantity'];
        final parsed = serverQty is int
            ? serverQty
            : int.tryParse(serverQty.toString()) ?? previous - 1;
        _setGridCartQuantity(item.id, parsed);
      }
    } catch (e) {
      if (!mounted) return;
      _setGridCartQuantity(item.id, previous);
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'حدث خطأ أثناء تحديث السلة'
            : 'Error updating cart',
        type: SnackType.error,
      );
    }
  }

  Future<void> _addNotifyRequest(ItemModel item) async {
    if (!_isLoggedIn || _currentUserId == null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
      return;
    }

    if (_currentUserId == item.seller.id) {
      return;
    }

    try {
      final result = await ApiService.addNotifyRequest(
        itemId: item.id,
        userId: _currentUserId!,
        storeId: item.storeid,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final alreadySubscribed = result['already_subscribed'] == true;
        setState(() {
          _notifySubscribed.add(item.id.toString());
        });

        if (alreadySubscribed) {
          showAppSnackbar(
            context,
            message: _lang == 'ar'
                ? 'أنت مشترك بالفعل في هذا التنبيه'
                : 'Already subscribed to this alert',
            type: SnackType.warning,
          );
        } else {
          showAppSnackbar(
            context,
            message: _lang == 'ar'
                ? 'سيتم إشعارك عند توفر المنتج ✓'
                : 'You will be notified when available',
            type: SnackType.success,
          );
        }
      } else {
        showAppSnackbar(
          context,
          message: result['error']?.toString() ?? 'فشل تسجيل التنبيه',
          type: SnackType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'حدث خطأ أثناء تسجيل التنبيه',
        type: SnackType.error,
      );
    }
  }

  void _onGridNotifyWhenAvailable(ItemModel item) {
    _addNotifyRequest(item);
  }

  String _itemImageUrl(ItemModel item) {
    if (item.media.isNotEmpty) {
      final url = item.media.first;
      if (url.contains("martit.s3") && url.endsWith(".png")) {
        return url.replaceAll(".png", ".webp");
      }
      return url;
    }
    return ItemMediaUrlUtil.thumbnail(
      storeId: item.storeid,
      itemId: item.id,
      itemIdx: item.idx,
    );
  }

  Widget _itemThumbnail({
    required ItemModel item,
    double? width,
    double? height,
    double iconSize = 30,
    bool showPlayBadge = true,
    Color? placeholderColor,
  }) {
    return UploadingMediaFrame(
      itemId: item.id,
      ready: ItemThumbnailWidget(
        storeId: item.storeid,
        itemId: item.id,
        itemIdx: item.idx,
        preferredUrl: item.media.isNotEmpty ? item.media.first : null,
        width: width,
        height: height,
        fit: BoxFit.cover,
        iconSize: iconSize,
        showPlayBadge: showPlayBadge,
        placeholderColor: placeholderColor,
      ),
    );
  }

  void _openItemFromGrid(ItemModel item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index < 0) return;

    setState(() {
      _currentIndex = index;
      _currentItemId = item.id;
    });

    if (!_isTikTokMode) {
      _setViewMode(_viewModeTiktok);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    });
  }

  void _trackLeavingItem(int itemIndex) {
    if (_itemViewStartTime == null ||
        itemIndex < 0 ||
        itemIndex >= _items.length) {
      return;
    }
    final item = _items[itemIndex];
    final seconds = DateTime.now().difference(_itemViewStartTime!).inSeconds;
    ApiService.trackInteraction(
      _currentUserId,
      item.id,
      'view',
      watchSeconds: seconds,
    );
    if (seconds < 2) {
      ApiService.trackInteraction(_currentUserId, item.id, 'skip');
    }
  }

  void _onPageChanged(int newIndex) {
    if (_items.isEmpty || newIndex >= _items.length) return;

    if (newIndex != _currentIndex && _currentIndex < _items.length) {
      _trackLeavingItem(_currentIndex);
    }

    final newStoreId = _items[newIndex].storeid;

    setState(() {
      _currentIndex = newIndex;
      _currentItemId = _items[newIndex].id;
    });

    _itemViewStartTime = DateTime.now();

    if (newStoreId != _currentStoreId) {
      _loadCategoriesForStore(newStoreId);
    }
  }

  Future<void> _loadNotifySubscriptions() async {
    if (!_isLoggedIn || _currentUserId == null) return;
    try {
      final ids = await ApiService.getUserNotifySubscriptions(_currentUserId!);
      if (!mounted) return;
      setState(() {
        _notifySubscribed = ids.map((e) => e.toString()).toSet();
      });
    } catch (e) {
      print('Error loading notify subscriptions: $e');
    }
  }

  String _sellerUserId(SellerModel seller) {
    return seller.uid.isNotEmpty ? seller.uid : seller.id;
  }

  bool _isOwnProduct(ItemModel item) {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    return _currentUserId == item.seller.uid ||
        _currentUserId == item.seller.id ||
        _currentUserId == _sellerUserId(item.seller);
  }

  bool _sheetIsDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _sheetBackground(BuildContext context) =>
      _sheetIsDark(context) ? AppColors.darkBackground : Colors.white;

  Color _sheetTileBackground(BuildContext context) =>
      _sheetIsDark(context) ? AppColors.darkSurface : const Color(0xFFF5F5F5);

  Color _sheetOnSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  bool _sameSeller(SellerModel a, SellerModel b) {
    return _sellerUserId(a) == _sellerUserId(b);
  }

  void _setFollowStateForSeller(SellerModel targetSeller, bool isFollowing) {
    for (var i = 0; i < _items.length; i++) {
      print(
        'Comparing: ${_items[i].seller.id} == ${targetSeller.id} '
        '(uid: ${_items[i].seller.uid} vs ${targetSeller.uid})',
      );
      if (!_sameSeller(_items[i].seller, targetSeller)) continue;

      _items[i] = ItemModel(
        id: _items[i].id,
        idx: _items[i].idx,
        storeid: _items[i].storeid,
        name: _items[i].name,
        nameEn: _items[i].nameEn,
        price: _items[i].price,
        quantity: _items[i].quantity,
        description: _items[i].description,
        descriptionArb: _items[i].descriptionArb,
        views: _items[i].views,
        media: _items[i].media,
        seller: SellerModel(
          id: _items[i].seller.id,
          uid: _items[i].seller.uid.isNotEmpty
              ? _items[i].seller.uid
              : _items[i].seller.id,
          name: _items[i].seller.name,
          avatar: _items[i].seller.avatar,
          token: _items[i].seller.token,
          isFollowing: isFollowing,
        ),
        interactions: _items[i].interactions,
      );
    }
  }

  Future<void> _checkLoginStatus() async {
    final currentUserIdx = await AuthService.getCurrentUserId();

    final isLoggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _currentUserId = currentUserIdx;
    });

    print('🔔 Loaded notify subscriptions: $_notifySubscribed');
    print('🔔 Current item ids: ${_items.map((e) => e.id).toList()}');

    if (isLoggedIn) {
      _loadNotifySubscriptions();
      _refreshCartQuantitiesFromServer();
    }

    if (isLoggedIn && currentUserIdx != null) {
      final scores = await ApiService.getUserScores(currentUserIdx);
      print('🎯 User category scores: ${scores['top_categories']}');
    }

    // ✅ تحميل المنتجات أولاً، ثم التصنيفات ستُحمّل تلقائياً
    final pinId = widget.initialItemId;
    _loadItems(
      uid: _currentUserId,
      isRefresh: true,
      initiItem: (pinId != null && pinId.isNotEmpty) ? pinId : '',
      pinnedItemId: (pinId != null && pinId.isNotEmpty) ? pinId : null,
    );
  }

  Future<void> _loadCategoriesForStore(String storeId) async {
    // ✅ تجنب إعادة التحميل إذا كان نفس المتجر
    if (storeId == _currentStoreId && _categories.isNotEmpty) return;
    if (_isLoadingCategories) return;

    setState(() {
      _isLoadingCategories = true;
    });

    try {
      // TEMP demo: cars-only categories for client pitch
      if (DemoCarsFeed.enabled) {
        setState(() {
          _categories = List<String>.from(DemoCarsFeed.categories);
          _currentStoreId = storeId;
          _isLoadingCategories = false;
          if (_selectedCategory != null &&
              !_categories.contains(_selectedCategory)) {
            _selectedCategory = null;
          }
        });
        return;
      }

      final categories = await ApiService.getCategories(storeId: storeId);
      setState(() {
        _categories = categories;
        _currentStoreId = storeId;
        _isLoadingCategories = false;

        // ✅ إذا التصنيف المختار غير موجود في المتجر الجديد، نرجع لـ "الكل"
        if (_selectedCategory != null &&
            !categories.contains(_selectedCategory)) {
          _selectedCategory = null;
        }
      });

      print('📦 Loaded ${categories.length} categories for store: $storeId');
    } catch (e) {
      print('Error loading categories for store $storeId: $e');
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadItems({
    bool isRefresh = false,
    String? uid,
    String? initiItem,
    String? category,
    String? pinnedItemId,
  }) async {
    if (_isLoading) {
      // Don't drop an explicit "open this product" request from search.
      if (pinnedItemId != null && pinnedItemId.isNotEmpty) {
        _pendingPinnedItemId = pinnedItemId;
      }
      return;
    }
    print("SSSSSS $uid");
    print("Category Filter: $category");

    setState(() {
      _isLoading = true;
      _hasError = false;
      if (isRefresh) {
        _currentPage = 0;
        // Keep existing items visible while refreshing so chrome (e.g. floating
        // cart) is not torn down by the empty-loading branch in build().
        if (pinnedItemId != null && pinnedItemId.isNotEmpty) {
          _currentIndex = 0;
          _currentItemId = pinnedItemId;
        }
      }
    });

    try {
      List<ItemModel> items;

      // TEMP demo: fixed cars catalog with Unsplash imagery
      if (DemoCarsFeed.enabled) {
        items = isRefresh || _items.isEmpty
            ? DemoCarsFeed.items(category: category)
            : <ItemModel>[];
        if (pinnedItemId != null && pinnedItemId.isNotEmpty && isRefresh) {
          final pinnedIndex = items.indexWhere(
            (item) => item.id == pinnedItemId,
          );
          if (pinnedIndex > 0) {
            final pinnedItem = items.removeAt(pinnedIndex);
            items.insert(0, pinnedItem);
          }
        }
        setState(() {
          if (isRefresh) {
            _items = items;
            // Never wipe cart badge state on feed refresh.
            if (pinnedItemId != null && pinnedItemId.isNotEmpty) {
              _currentIndex = 0;
              _currentItemId = pinnedItemId;
            }
          } else {
            _items.addAll(items);
          }
          _syncCartQuantitiesFromItems(items);
          _isLoading = false;
          _currentPage++;
          if (_itemViewStartTime == null && _items.isNotEmpty) {
            _itemViewStartTime = DateTime.now();
          }
        });
        if (isRefresh &&
            pinnedItemId != null &&
            pinnedItemId.isNotEmpty &&
            _pageController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          });
        }
        if (items.isNotEmpty && isRefresh) {
          _loadCategoriesForStore(items[0].storeid);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeStartHomeTour();
          });
        }
        if (isRefresh && _isLoggedIn) {
          await _refreshCartQuantitiesFromServer();
        }
        await _consumePendingPinnedItem();
        return;
      }

      final resolvedInitialItemId = (initiItem != null && initiItem.isNotEmpty)
          ? initiItem
          : (initiItem == '' ? '' : widget.initialItemId);

      // ✅ نجيب الـ user_id سواء مسجل دخول أو لأ
      final currentUserId = _isLoggedIn
          ? await AuthService.getCurrentUserId()
          : null;

      final prefs = await SharedPreferences.getInstance();
      String simCountry = prefs.getString('selected_country') ?? 'QA';
      print('🌍 Selected country: $simCountry');
      print(
        '🗣️ Selected language: ${LocalizationService.instance.currentLanguage}',
      );

      if (_isLoggedIn && currentUserId != null) {
        // ✅ لو مسجل دخول، نستخدم fetchItemsWithLikes
        items = await ApiService.fetchItemsWithLikes(
          userId: currentUserId,
          limit: 10,
          offset: isRefresh ? 0 : _items.length,
          initialItemId: resolvedInitialItemId,
          category: category,
          country: simCountry,
          pinnedItemId: isRefresh ? pinnedItemId : null,
        );
      } else {
        // ✅ لو مش مسجل، نستخدم fetchItems عادي (بدون user_id)
        items = await ApiService.fetchItems(
          page: isRefresh ? 0 : _currentPage,
          userId: uid,
          initialItemId: resolvedInitialItemId,
          category: category,
          country: simCountry,
          pinnedItemId: isRefresh ? pinnedItemId : null,
        );
      }

      if (isRefresh) {
        items = await _resolvePinnedItems(
          items,
          pinnedItemId: pinnedItemId ?? _pendingPinnedItemId,
          userId: currentUserId,
          country: simCountry,
        );
      }

      setState(() {
        if (isRefresh) {
          _items = items;
          // Keep cart quantities across feed reloads (search pin, pull-to-
          // refresh, category change). Full cart is re-synced from API below.
          if (pinnedItemId != null && pinnedItemId.isNotEmpty) {
            _currentIndex = 0;
            _currentItemId = pinnedItemId;
          }
        } else {
          _items.addAll(items);
        }
        _syncCartQuantitiesFromItems(items);
        _isLoading = false;
        _currentPage++;
        if (_itemViewStartTime == null && _items.isNotEmpty) {
          _itemViewStartTime = DateTime.now();
        }
      });

      if (isRefresh &&
          pinnedItemId != null &&
          pinnedItemId.isNotEmpty &&
          _pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
      }

      // ✅ تحميل التصنيفات للمتجر الأول بعد تحميل المنتجات
      if (items.isNotEmpty && isRefresh) {
        _loadCategoriesForStore(items[0].storeid);
      }

      if (items.isNotEmpty && isRefresh) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeStartHomeTour();
        });
      }

      if (isRefresh && _isLoggedIn) {
        await _refreshCartQuantitiesFromServer();
      }

      await _consumePendingPinnedItem();
    } catch (e) {
      print('API Error: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });

      await _consumePendingPinnedItem();

      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'خطأ في الاتصال بالخادم: $e'
            : 'Server connection error: $e',
        type: SnackType.error,
      );
    }
  }

  Future<void> _maybeStartHomeTour() async {
    if (!mounted || _showHomeTour || _items.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool('pending_home_tour') ?? false;
    if (!pending) return;

    if (!_isTikTokMode) {
      await _setViewMode(_viewModeTiktok);
    }

    // Wait for side actions / overlays to lay out.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || _items.isEmpty) return;

    setState(() => _showHomeTour = true);
  }

  Future<void> _finishHomeTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_home_tour', false);
    await prefs.setBool('home_tour_done', true);
    if (!mounted) return;
    setState(() => _showHomeTour = false);
  }

  List<HomeTourStep> _homeTourSteps() {
    return [
      const HomeTourStep(
        titleAr: 'مرحباً بك في MartIt',
        titleEn: 'Welcome to MartIt',
        bodyAr:
            'هذا شرح سريع لواجهة التطبيق. سنمر على الأزرار واحداً تلو الآخر.',
        bodyEn:
            'A quick tour of the home screen. We will highlight each control step by step.',
        preferCircle: false,
      ),
      HomeTourStep(
        targetKey: _tourAddKey,
        titleAr: 'إضافة منتج',
        titleEn: 'Add a product',
        bodyAr: 'من هنا تقدر تضيف منتجك أو فيديوك للبيع في التطبيق.',
        bodyEn: 'Use this to post your product or video for sale.',
      ),
      HomeTourStep(
        targetKey: _tourSwipeKey,
        titleAr: 'تمرير المنتجات',
        titleEn: 'Swipe products',
        bodyAr: 'اسحب لأعلى أو لأسفل لاستكشاف المنتجات مثل تيك توك.',
        bodyEn: 'Swipe up or down to browse products like TikTok.',
        preferCircle: false,
        showSwipeHint: true,
      ),
      HomeTourStep(
        targetKey: _tourSellerKey,
        titleAr: 'البائع',
        titleEn: 'Seller',
        bodyAr: 'اضغط على صورة البائع لفتح ملفه الشخصي ومتابعة متجره.',
        bodyEn: 'Tap the seller avatar to open their profile and shop.',
      ),
      HomeTourStep(
        targetKey: _tourLikeKey,
        titleAr: 'الإعجاب',
        titleEn: 'Like',
        bodyAr: 'أعجب بالمنتج عشان يظهر أكثر لمستخدمين مشابهين لك.',
        bodyEn: 'Like a product to boost it for people with similar taste.',
      ),
      HomeTourStep(
        targetKey: _tourCommentKey,
        titleAr: 'التعليقات',
        titleEn: 'Comments',
        bodyAr: 'افتح التعليقات واسأل البائع أو شارك رأيك.',
        bodyEn: 'Open comments to ask the seller or share your thoughts.',
      ),
      HomeTourStep(
        targetKey: _tourShareKey,
        titleAr: 'المشاركة',
        titleEn: 'Share',
        bodyAr: 'شارك المنتج مع أصدقائك برابط سريع.',
        bodyEn: 'Share the product with friends via a quick link.',
      ),
      HomeTourStep(
        targetKey: _tourCartKey,
        titleAr: 'السلة',
        titleEn: 'Cart',
        bodyAr: 'أضف المنتج إلى سلة التسوق للشراء لاحقاً.',
        bodyEn: 'Add the product to your cart to buy later.',
      ),
      HomeTourStep(
        targetKey: _tourInfoKey,
        titleAr: 'تفاصيل المنتج',
        titleEn: 'Product details',
        bodyAr: 'هنا اسم البائع، عنوان المنتج، والسعر.',
        bodyEn: 'Here you see the seller, product title, and price.',
        preferCircle: false,
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant HomeFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rebuildToken != oldWidget.rebuildToken &&
        widget.initialItemId != null &&
        widget.initialItemId!.isNotEmpty) {
      // Search / deep-link open: refresh feed and pin the selected item at
      // page 0. Without isRefresh the old feed page stayed on screen.
      _openPinnedFeedItem(widget.initialItemId!);
    }
  }

  Future<void> _openPinnedFeedItem(String itemId) async {
    setState(() {
      _selectedCategory = null;
      _currentIndex = 0;
      _currentItemId = itemId;
    });

    await _loadItems(
      isRefresh: true,
      uid: _currentUserId,
      category: null,
      pinnedItemId: itemId,
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  Future<void> _consumePendingPinnedItem() async {
    final pending = _pendingPinnedItemId;
    if (pending == null || pending.isEmpty || !mounted) return;
    _pendingPinnedItemId = null;
    await _openPinnedFeedItem(pending);
  }

  /// Called by [MainNavigationScreen] for the center "+" control.
  Future<void> onAddProductPressed() => _onAddProductPressed();

  /// Home tab re-tap: subscribe to restock notify when badge is showing.
  Future<void> onHomeTabRetapped() async {
    if (_shouldShowHomeNotifyBadge() &&
        _items.isNotEmpty &&
        _currentIndex < _items.length) {
      await _addNotifyRequest(_items[_currentIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    // Floating cart lives in the outer Stack so feed reloads / empty-loading
    // states never remove it. It self-hides when the cart count is 0.
    final feedBody = Stack(
      children: [
        if (_isLoading && _items.isEmpty)
          const Center(child: CircularProgressIndicator(color: _brandPrimary))
        else ...[
          _buildHomeFeed(key: const ValueKey('home_feed')),
          if (_showHeartAnimation)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _heartAnimController!,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _heartOpacityAnim!.value,
                        child: Transform.scale(
                          scale: _heartScaleAnim!.value,
                          child: Icon(
                            Icons.favorite,
                            color: _heartColor,
                            size: 120,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          _buildBottomInfo(),
          _buildSideActions(),
          if (_items.isEmpty) _buildEmptyFeedState(),
          if (_showHomeTour) ...[
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.of(context).size.height * 0.34,
              child: IgnorePointer(
                child: Center(
                  child: SizedBox(key: _tourSwipeKey, width: 150, height: 150),
                ),
              ),
            ),
            Positioned.fill(
              child: HomeTourOverlay(
                steps: _homeTourSteps(),
                onFinish: _finishHomeTour,
              ),
            ),
          ],
        ],
        _buildFloatingCartButton(),
      ],
    );

    final scaffold = Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        bottomNavigationBar: widget.showBottomNav
            ? _buildBottomNavBar(lang)
            : null,
        body: feedBody,
      ),
    );

    if (!widget.showBottomNav) {
      // Exit / back handling lives on MainNavigationScreen.
      return scaffold;
    }

    return WillPopScope(
      onWillPop: () async {
        bool exitApp =
            await showDialog(
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
      },
      child: scaffold,
    );
  }

  Future<void> _onAddProductPressed() async {
    if (!_isLoggedIn) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
      return;
    }

    final uid = await AuthService.getCurrentUID();
    final val = await AuthService.getUserStatus(uid);
    if (!mounted) return;

    if (val['success'] == false &&
        (val['error'] == 'user not found' || val['error'] == 'uid missing')) {
      await AuthService.logout();
      setState(() {
        _isLoggedIn = false;
        _currentUserId = null;
      });
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'انتهت الجلسة، يرجى تسجيل الدخول مجدداً'
            : 'Session expired, please login again',
        type: SnackType.error,
      );
      return;
    }

    if (val['status']?.toString() == '2') {
      showAppSnackbar(
        context,
        message:
            'تم حظرك نهائياً من إستخدام التطبيق يرجى التواصل مع الدعم لحل المشكلة!',
        type: SnackType.error,
      );
      return;
    }

    _handleAddProduct();
  }

  Widget _buildBottomNavBar(String lang) {
    final isAr = lang == 'ar';
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Iconsax.home_2,
                    activeIcon: Iconsax.home_15,
                    label: isAr ? 'الرئيسية' : 'Home',
                    showNotifyBadge: _shouldShowHomeNotifyBadge(),
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Iconsax.search_normal,
                    activeIcon: Iconsax.search_normal_1,
                    label: isAr ? 'استكشف' : 'Discover',
                  ),
                  const SizedBox(width: 72),
                  _buildNavItem(
                    index: 3,
                    icon: Iconsax.message,
                    activeIcon: Iconsax.message5,
                    label: isAr ? 'المحادثات' : 'Inbox',
                  ),
                  _buildNavItem(
                    index: 4,
                    icon: Iconsax.user,
                    activeIcon: Iconsax.profile_circle5,
                    label: isAr ? 'حسابي' : 'Profile',
                  ),
                ],
              ),
              Positioned(top: -22, child: _buildCenterAddButton()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAddButton() {
    return GestureDetector(
      key: _tourAddKey,
      onTap: _onAddProductPressed,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: _brandPrimary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black, width: 4),
          boxShadow: [
            BoxShadow(
              color: _brandPrimary.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Iconsax.add, color: Colors.white, size: 30),
      ),
    );
  }

  bool _shouldShowHomeNotifyBadge() {
    if (_items.isEmpty || _currentIndex >= _items.length) return false;
    final item = _items[_currentIndex];
    if (item.quantity > 0 || _isOwnProduct(item)) return false;
    return !_notifySubscribed.contains(item.id.toString());
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    bool showNotifyBadge = false,
  }) {
    final selected = _bottomNavIndex == index;
    final color = selected ? _brandPrimary : _navUnselected;
    return Expanded(
      child: InkWell(
        onTap: () => _onBottomNavTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? activeIcon : icon, color: color, size: 24),
                if (showNotifyBadge)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
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

  Future<void> _onBottomNavTap(int index) async {
    if (index == 0) {
      setState(() => _bottomNavIndex = 0);
      // Notify badge on Home: tap to subscribe for restock alerts.
      if (_shouldShowHomeNotifyBadge() &&
          _items.isNotEmpty &&
          _currentIndex < _items.length) {
        await _addNotifyRequest(_items[_currentIndex]);
      }
      return;
    }

    if (index == 2) {
      await _onAddProductPressed();
      return;
    }

    setState(() => _bottomNavIndex = index);

    switch (index) {
      case 1:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
        break;
      case 3:
        await _openNavChat();
        break;
      case 4:
        await _openNavProfile();
        break;
    }

    if (mounted) setState(() => _bottomNavIndex = 0);
  }

  Future<void> _openNavChat() async {
    final userId = await AuthService.getCurrentUserId();
    if (!mounted) return;
    if (userId == null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConversationsScreen(userId: userId)),
    );
  }

  Future<void> _openNavProfile() async {
    final userId = await AuthService.getCurrentUserId();
    if (!mounted) return;
    if (userId == null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  Widget _buildHomeFeed({Key? key}) {
    return PageView.builder(
      key: key,
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (index) {
        final actualIndex = index % _items.length;
        _onPageChanged(actualIndex);

        if (actualIndex >= _items.length - 3 && !_isLoading) {
          _loadItems(
            uid: _items[actualIndex].seller.id,
            initiItem: '',
            category: _selectedCategory,
          );
        }
      },
      itemCount: _items.isEmpty ? 0 : null,
      itemBuilder: (context, index) {
        if (_items.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final actualIndex = index % _items.length;
        return _buildVideoItem(_items[actualIndex], actualIndex);
      },
    );
  }

  Widget _buildGridFeed({Key? key}) {
    final topPadding = _gridHeaderHeight(context);

    return RefreshIndicator(
      key: key,
      color: AppColors.primary,
      onRefresh: () => _loadItems(
        isRefresh: true,
        uid: _currentUserId,
        category: _selectedCategory,
      ),
      child: GridView.builder(
        controller: _gridScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12, topPadding, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        itemCount: _items.length + (_isLoading ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return _buildGridProductCard(_items[index]);
        },
      ),
    );
  }

  Map<String, dynamic> _productDetailItemMap(ItemModel item) {
    return {
      'id': item.id,
      'idx': item.idx,
      'storeid': item.storeid,
      'name': item.name,
      'eng': item.nameEn,
      'price': item.price,
      'qtt': item.quantity,
      'description': item.description,
      'description_arb': item.descriptionArb,
      'seller_name': item.seller.name,
      'seller_id': item.seller.id,
    };
  }

  Widget _buildGridProductCard(ItemModel item) {
    final showCart = !_isLoggedIn || !_isOwnProduct(item);

    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProductDetailScreen(item: _productDetailItemMap(item)),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: _itemThumbnail(
                    item: item,
                    height: 160,
                    iconSize: 40,
                    placeholderColor: context.appSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.localizedName(
                        LocalizationService.instance.currentLanguage,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Iconsax.shop, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.seller.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.price} ريال',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (showCart)
                          _InlineCartControl(
                            cartQuantity: _gridCartQuantity(item),
                            stockQuantity: item.quantity,
                            variant: _InlineCartVariant.grid,
                            onAdd: () => _onGridCartAdd(item),
                            onRemove: () => _onGridCartRemove(item),
                            onNotify: () => _onGridNotifyWhenAvailable(item),
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
    );
  }

  Widget _buildEmptyFeedState() {
    final lang = LocalizationService.instance.currentLanguage;
    final textColor = _isTikTokMode ? Colors.white : context.appTextPrimary;
    final iconColor = _isTikTokMode ? Colors.white : Colors.grey;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.box, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text(
            lang == 'ar' ? 'لا توجد منتجات' : 'No products found',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                _loadItems(isRefresh: true, category: _selectedCategory),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(lang == 'ar' ? 'إعادة المحاولة' : 'Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesContent() {
    if (_isLoadingCategories) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _categories.length + 1,
      itemBuilder: (context, index) => _buildCategoryItemAt(index),
    );
  }

  Widget _buildCategoryItemAt(int index) {
    final lang = LocalizationService.instance.currentLanguage;
    if (index == 0) {
      return _buildCategoryChip(
        label: lang == 'ar' ? 'الكل' : 'All',
        isSelected: _selectedCategory == null,
        onTap: () {
          if (_selectedCategory == null) return;

          setState(() {
            _selectedCategory = null;
          });
          _loadItems(isRefresh: true, uid: _currentUserId, category: null);
        },
      );
    }

    final category = _categories[index - 1];
    return _buildCategoryChip(
      label: category,
      isSelected: _selectedCategory == category,
      onTap: () {
        if (_selectedCategory == category) return;

        setState(() {
          _selectedCategory = category;
        });
        _loadItems(isRefresh: true, uid: _currentUserId, category: category);
      },
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final unselectedBg = _isTikTokMode
        ? Colors.white.withOpacity(0.2)
        : Colors.white;
    final unselectedBorder = _isTikTokMode
        ? Colors.white.withOpacity(0.3)
        : Colors.grey.shade300;
    final labelColor = isSelected
        ? Colors.white
        : (_isTikTokMode ? Colors.white : context.appTextPrimary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : unselectedBorder,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              shadows: _isTikTokMode && !isSelected
                  ? const [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.black45,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCartButton() {
    final count = _totalCartCount;
    final visible = count > 0;
    final top = MediaQuery.of(context).padding.top + 10;

    // Top-right corner (leading in RTL). Side actions sit lower on the
    // trailing edge, so this stays clear of like/comment/share/cart qty.
    return Positioned(
      top: top,
      right: 14,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedScale(
            scale: visible ? 1 : 0.85,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: visible ? _openCartScreen : null,
                customBorder: const CircleBorder(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF5C33EA,
                            ).withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Iconsax.shopping_cart5,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    if (count > 0)
                      PositionedDirectional(
                        top: -2,
                        end: -2,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC6FF3D),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.15),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              color: Color(0xFF0E0E10),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideActions() {
    if (_items.isEmpty || _currentIndex >= _items.length) {
      return const SizedBox();
    }

    final lang = LocalizationService.instance.currentLanguage;
    final item = _items[_currentIndex];
    print('seller.uid: ${item.seller.uid}, seller.id: ${item.seller.id}');
    final sellerUserId = item.seller.uid.isNotEmpty
        ? item.seller.uid
        : item.seller.id;
    const countStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      shadows: [
        Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black54),
      ],
    );

    final isAr = LocalizationService.instance.currentLanguage == 'ar';
    return Positioned(
      right: isAr ? null : 10,
      left: isAr ? 10 : null,
      bottom: 136,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            key: _tourSellerKey,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _brandPrimary, width: 2),
              ),
              child: SmartAvatarWidget(
                userId: sellerUserId,
                name: item.seller.name,
                size: 48,
                fallbackUrl: item.seller.avatar,
                backgroundColor: _brandPrimary,
                initialsStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: item.seller.id),
                ),
              );
            },
          ),

          if (_isLoggedIn && !_isOwnProduct(item))
            _buildActionButton(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: item.seller.isFollowing
                      ? Colors.white24
                      : _brandPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.seller.isFollowing
                      ? (lang == 'ar' ? 'يتابع' : 'Following')
                      : (lang == 'ar' ? 'متابعة' : 'Follow'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () => _followUser(item),
            ),

          _buildActionButton(
            key: _tourLikeKey,
            child: Column(
              children: [
                Icon(
                  item.interactions.isLiked ? Iconsax.heart5 : Iconsax.heart,
                  color: item.interactions.isLiked ? Colors.red : Colors.white,
                  size: 30,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_formatCount(item.interactions.likes), style: countStyle),
              ],
            ),
            onTap: () => _handleLike(item),
          ),

          _buildActionButton(
            key: _tourCommentKey,
            child: Column(
              children: [
                const Icon(
                  Iconsax.message,
                  color: Colors.white,
                  size: 30,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCount(item.interactions.comments),
                  style: countStyle,
                ),
              ],
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CommentsModal(
                  itemId: item.id,
                  isLoggedIn: _isLoggedIn,
                  items: item,
                ),
              );
            },
          ),

          _buildActionButton(
            key: _tourShareKey,
            child: Column(
              children: [
                const Icon(
                  Iconsax.share,
                  color: Colors.white,
                  size: 30,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_formatCount(item.interactions.shares), style: countStyle),
              ],
            ),
            onTap: () => _handleShare(item),
          ),

          if (!_isOwnProduct(item) && item.quantity > 0)
            Padding(
              key: _tourCartKey,
              padding: const EdgeInsets.all(8),
              child: _InlineCartControl(
                cartQuantity: _gridCartQuantity(item),
                stockQuantity: item.quantity,
                variant: _InlineCartVariant.feed,
                onAdd: () => _onGridCartAdd(item),
                onRemove: () => _onGridCartRemove(item),
                onNotify: () => _onGridNotifyWhenAvailable(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    Key? key,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(8), child: child),
    );
  }

  Widget _buildBottomInfo() {
    if (_items.isEmpty || _currentIndex >= _items.length) {
      return const SizedBox();
    }

    final lang = LocalizationService.instance.currentLanguage;
    final item = _items[_currentIndex];

    final isAr = LocalizationService.instance.currentLanguage == 'ar';
    return Positioned(
      left: isAr ? 72 : 0,
      right: isAr ? 0 : 72,
      bottom: 128,
      child: Container(
        key: _tourInfoKey,
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xCC000000), Color(0x66000000), Colors.transparent],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Iconsax.user, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item.seller.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.localizedName(LocalizationService.instance.currentLanguage),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black54,
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _brandPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.tag, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${item.price} ريال',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (item.quantity == 0)
                  _buildOutOfStockNotifyChip(item, lang)
                else
                  Text(
                    '${item.quantity} ${item.quantity >= 3 && item.quantity <= 9 ? "Pcs" : "Pc"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutOfStockNotifyChip(ItemModel item, String lang) {
    final isSubscribed = _notifySubscribed.contains(item.id.toString());
    final canNotify = !_isOwnProduct(item);
    return GestureDetector(
      key: _tourCartKey,
      onTap: canNotify && !isSubscribed ? () => _addNotifyRequest(item) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSubscribed ? Colors.white24 : Colors.red.shade600,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSubscribed ? Iconsax.notification5 : Iconsax.notification,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 4),
            Text(
              isSubscribed
                  ? (lang == 'ar' ? 'تم تسجيل التنبيه' : 'Alert set')
                  : canNotify
                  ? (lang == 'ar' ? 'نفذ · ذكرني' : 'Sold out · Notify')
                  : (lang == 'ar' ? 'نفذ من المخزون' : 'Out of Stock'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoItem(ItemModel item, int actualIndex) {
    return GestureDetector(
      onDoubleTap: () {
        if (_items.isEmpty || actualIndex >= _items.length) return;
        final tappedItem = _items[actualIndex];
        if (_currentUserId == tappedItem.seller.id) return;

        final wasLiked = tappedItem.interactions.isLiked;
        _handleLike(tappedItem);
        _triggerHeartAnimation(!wasLiked);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: UploadingMediaFrame(
          itemId: item.id,
          ready: item.media.isNotEmpty
              ? MediaViewerWidget(
                  mediaUrls: item.media,
                  itmId: item.id,
                  itmIdx: item.idx,
                  storeid: item.storeid,
                  autoPlayVideo: true,
                  showControls: false,
                  showIndicators: item.media.length > 1,
                )
              : const Center(
                  child: Icon(Iconsax.image, color: Colors.white, size: 80),
                ),
        ),
      ),
    );
  }

  String? _publishedItemIdFromResult(dynamic result) {
    if (result == null) return null;
    if (result is Map) {
      final id = result['id']?.toString();
      return (id != null && id.isNotEmpty) ? id : null;
    }
    final id = result.toString().trim();
    if (id.isEmpty || id == 'null') return null;
    return id;
  }

  SellerModel _sellerForCurrentUser() {
    for (final item in _items) {
      if (_isOwnProduct(item)) return item.seller;
    }
    final uid = _currentUserId ?? '';
    return SellerModel(
      id: uid,
      uid: uid,
      name: '',
      avatar: '',
    );
  }

  ItemModel _itemFromPublishSnapshot(Map snapshot, String itemId) {
    final media = <String>[];
    final rawMedia = snapshot['media'];
    if (rawMedia is List) {
      media.addAll(
        rawMedia.map((e) => e.toString()).where((e) => e.isNotEmpty),
      );
    }
    return ItemModel(
      id: itemId,
      idx: snapshot['idx']?.toString() ?? '',
      storeid: snapshot['storeid']?.toString() ?? '1',
      name: snapshot['name']?.toString() ?? '',
      nameEn: snapshot['eng']?.toString() ?? '',
      price: snapshot['price']?.toString() ?? '0',
      quantity: int.tryParse(snapshot['quantity']?.toString() ?? '0') ?? 0,
      description: snapshot['description']?.toString() ?? '',
      descriptionArb: snapshot['description_arb']?.toString() ?? '',
      views: 0,
      media: media,
      seller: _sellerForCurrentUser(),
      interactions: InteractionsModel(
        likes: 0,
        comments: 0,
        shares: 0,
        cartQuantity: 0,
      ),
    );
  }

  List<ItemModel> _ensureItemPinned(
    List<ItemModel> items,
    String? pinnedItemId,
  ) {
    if (pinnedItemId == null || pinnedItemId.isEmpty) return items;
    final next = List<ItemModel>.from(items);
    final index = next.indexWhere((item) => item.id == pinnedItemId);
    if (index == 0) return next;
    if (index > 0) {
      next.insert(0, next.removeAt(index));
      return next;
    }
    final localIndex = _items.indexWhere((item) => item.id == pinnedItemId);
    if (localIndex != -1) {
      next.insert(0, _items[localIndex]);
    }
    return next;
  }

  Future<List<ItemModel>> _resolvePinnedItems(
    List<ItemModel> items, {
    String? pinnedItemId,
    String? userId,
    String? country,
  }) async {
    if (pinnedItemId == null || pinnedItemId.isEmpty) return items;
    var next = _ensureItemPinned(items, pinnedItemId);
    if (next.isNotEmpty && next.first.id == pinnedItemId) return next;

    final fetchedItem = await ApiService.fetchItemById(
      itemId: pinnedItemId,
      userId: userId,
      country: country,
    );
    if (fetchedItem != null) {
      next = List<ItemModel>.from(next)..insert(0, fetchedItem);
      return next;
    }
    return _ensureItemPinned(next, pinnedItemId);
  }

  void _onReturnFromAddProductScreen(dynamic result) {
    final itemId = _publishedItemIdFromResult(result);
    if (itemId == null) return;

    widget.onSwitchToHomeTab?.call();

    ItemModel? snapshotItem;
    if (result is Map) {
      snapshotItem = _itemFromPublishSnapshot(result, itemId);
    }

    unawaited(_showPublishedItemOnFeed(itemId, snapshotItem));
  }

  Future<void> _showPublishedItemOnFeed(
    String itemId,
    ItemModel? snapshotItem,
  ) async {
    if (!mounted) return;

    if (!_isTikTokMode) {
      await _setViewMode(_viewModeTiktok);
    }

    if (!mounted) return;
    setState(() {
      _selectedCategory = null;
      _currentIndex = 0;
      _currentItemId = itemId;
      if (snapshotItem != null) {
        _items.removeWhere((item) => item.id == itemId);
        _items.insert(0, snapshotItem);
      }
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    await _loadItems(
      isRefresh: true,
      uid: _currentUserId,
      category: null,
      pinnedItemId: itemId,
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _handleAddProduct() async {
    _showAddProductBottomSheet();
  }

  void _showAddProductBottomSheet() {
    final lang = LocalizationService.instance.currentLanguage;
    final isAr = lang == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaPickerSheet(
        title: isAr ? 'إضافة منتج جديد' : 'Add New Product',
        subtitle: isAr
            ? 'اختر طريقة إضافة المحتوى لمنتجك'
            : 'Choose how to add content for your product',
        options: [
          MediaPickerOption(
            icon: Iconsax.camera5,
            label: isAr ? 'إضافة صورة' : 'Add Photo',
            subtitle: isAr ? 'التقط صورة للمنتج' : 'Take a product photo',
            onTap: () {
              Navigator.pop(sheetContext);
              _showImageSourceBottomSheet();
            },
          ),
          MediaPickerOption(
            icon: Iconsax.video_play,
            label: isAr ? 'إضافة فيديو' : 'Add Video',
            subtitle: isAr ? 'سجل فيديو للمنتج' : 'Record a product video',
            onTap: () {
              Navigator.pop(sheetContext);
              _showVideoSourceBottomSheet();
            },
          ),
        ],
      ),
    );
  }

  void _showImageSourceBottomSheet() {
    final lang = LocalizationService.instance.currentLanguage;
    final isAr = lang == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaPickerSheet(
        title: isAr ? 'إضافة صورة' : 'Add Photo',
        subtitle: isAr
            ? 'التقط صورة جديدة أو اختر من المعرض'
            : 'Take a new photo or pick from gallery',
        onBack: () {
          Navigator.pop(sheetContext);
          _showAddProductBottomSheet();
        },
        options: [
          MediaPickerOption(
            icon: Iconsax.camera5,
            label: isAr ? 'التقاط صورة' : 'Take Photo',
            subtitle: isAr
                ? 'استخدم الكاميرا لالتقاط صورة جديدة'
                : 'Use camera to take a new photo',
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraScreen(isVideo: false),
                ),
              ).then(_openAddProductFromCamera);
            },
          ),
          MediaPickerOption(
            icon: Iconsax.gallery5,
            label: isAr ? 'اختيار من المعرض' : 'Choose from Gallery',
            subtitle: isAr
                ? 'اختر صورة من معرض الصور'
                : 'Choose from photo gallery',
            onTap: () {
              Navigator.pop(sheetContext);
              _pickImageFromGallery();
            },
          ),
        ],
      ),
    );
  }

  void _showVideoSourceBottomSheet() {
    final lang = LocalizationService.instance.currentLanguage;
    final isAr = lang == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaPickerSheet(
        title: isAr ? 'إضافة فيديو' : 'Add Video',
        subtitle: isAr
            ? 'سجّل فيديو جديد أو اختر من المعرض'
            : 'Record a new video or pick from gallery',
        onBack: () {
          Navigator.pop(sheetContext);
          _showAddProductBottomSheet();
        },
        options: [
          MediaPickerOption(
            icon: Iconsax.video_circle,
            label: isAr ? 'تسجيل فيديو' : 'Record Video',
            subtitle: isAr
                ? 'استخدم الكاميرا لتسجيل فيديو جديد'
                : 'Use camera to record a new video',
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraScreen(isVideo: true),
                ),
              ).then(_openAddProductFromCamera);
            },
          ),
          MediaPickerOption(
            icon: Iconsax.gallery5,
            label: isAr ? 'اختيار من المعرض' : 'Choose from Gallery',
            subtitle: isAr
                ? 'اختر فيديو من معرض الفيديوهات'
                : 'Choose from video gallery',
            onTap: () {
              Navigator.pop(sheetContext);
              _pickVideoFromGallery();
            },
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() async {
    final lang = LocalizationService.instance.currentLanguage;
    final item = (_items.isNotEmpty && _currentIndex < _items.length)
        ? _items[_currentIndex]
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = _sheetIsDark(sheetContext);
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.75,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: _sheetBackground(sheetContext),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white30 : Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (item != null) _buildMoreSheetHeader(item),
                const Divider(height: 32, thickness: 0.5),
                Row(
                  children: [
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.user,
                        label: lang == 'ar' ? 'الملف الشخصي' : 'Profile',
                        backgroundColor: const Color(0xFFE3F2FD),
                        iconColor: const Color(0xFF1565C0),
                        onTap: _showCurrentUserProfile,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.shopping_cart,
                        label: lang == 'ar' ? 'سلة التسوق' : 'Shopping Cart',
                        backgroundColor: const Color(0xFFE8F5E9),
                        iconColor: const Color(0xFF2E7D32),
                        onTap: _showShoppingCart,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.bag_tick,
                        label: lang == 'ar'
                            ? 'طلبات العملاء'
                            : 'Customer Orders',
                        backgroundColor: const Color(0xFFF3E5F5),
                        iconColor: const Color(0xFF7B1FA2),
                        onTap: _showCustomerOrders,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.bag,
                        label: lang == 'ar' ? 'طلباتي' : 'My Orders',
                        backgroundColor: const Color(0xFFFFF3E0),
                        iconColor: AppColors.secondary,
                        onTap: _showMyOrders,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.message,
                        label: lang == 'ar' ? 'المحادثات' : 'Conversations',
                        backgroundColor: const Color(0xFFE0F2F1),
                        iconColor: const Color(0xFF00695C),
                        onTap: _showConversations,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.document_text,
                        label: lang == 'ar' ? 'الوصف' : 'Description',
                        backgroundColor: const Color(0xFFFFFDE7),
                        iconColor: const Color(0xFFF9A825),
                        onTap: _showItemDescription,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMoreGridCard(
                  icon: Iconsax.warning_2,
                  label: lang == 'ar' ? 'بلغ عن المحتوى' : 'Report Content',
                  backgroundColor: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFC62828),
                  onTap: _showReportOptions,
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                _buildMoreGridCard(
                  icon: Iconsax.user_remove,
                  label: lang == 'ar' ? 'حظر المستخدم' : 'Block User',
                  backgroundColor: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFC62828),
                  onTap: _showBlockUserOptions,
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                _buildMoreGridCard(
                  icon: Iconsax.logout,
                  label: lang == 'ar' ? 'تسجيل الخروج' : 'Logout',
                  backgroundColor: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFC62828),
                  onTap: _handleLogout,
                  fullWidth: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      lang == 'ar' ? 'إغلاق' : 'Close',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(sheetContext).padding.bottom + 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreSheetHeader(ItemModel item) {
    return Row(
      children: [
        ClipOval(
          child: _itemThumbnail(
            item: item,
            width: 60,
            height: 60,
            iconSize: 24,
            showPlayBadge: false,
            placeholderColor: context.appSurfaceVariant,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${item.price} ريال',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoreGridCard({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : backgroundColor;
    final resolvedIconColor = isDark ? Colors.white70 : iconColor;
    final labelColor = isDark
        ? Colors.white70
        : iconColor.withValues(alpha: 0.9);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            vertical: fullWidth ? 14 : 18,
            horizontal: fullWidth ? 16 : 8,
          ),
          child: fullWidth
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 28, color: resolvedIconColor),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 28, color: resolvedIconColor),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showShoppingCart() async {
    Navigator.pop(context); // Close bottom sheet
    await _openCartScreen();
  }

  void _showConversations() async {
    Navigator.pop(context); // Close bottom sheet

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'يجب تسجيل الدخول أولاً'
            : 'Please login first',
        type: SnackType.error,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationsScreen(userId: currentUserId),
      ),
    );
  }

  void _showCustomerOrders() async {
    Navigator.pop(context); // Close bottom sheet

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'يجب تسجيل الدخول أولاً'
            : 'Please login first',
        type: SnackType.error,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CustomerOrdersScreen()),
    );
  }

  void _showMyOrders() async {
    Navigator.pop(context); // Close bottom sheet

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'يجب تسجيل الدخول أولاً'
            : 'Please login first',
        type: SnackType.error,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
    );
  }

  void _handleLogout() async {
    Navigator.pop(context); // Close bottom sheet
    await AuthService.logout();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _currentUserId = null;
    });
    showAppSnackbar(
      context,
      message: _lang == 'ar'
          ? 'تم تسجيل الخروج بنجاح'
          : 'Logged out successfully',
      type: SnackType.success,
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _showCurrentUserProfile() async {
    Navigator.pop(context); // Close bottom sheet

    // Get current user ID from AuthService
    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: currentUserId),
        ),
      );
    } else {
      showAppSnackbar(
        context,
        message: 'لم يتم العثور على بيانات المستخدم',
        type: SnackType.error,
      );
    }
  }

  void _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final result = await picker.pickMultiImage();
    final imagePaths = result.map((image) => image.path).toList();
    _openAddProductWithMedia(imagePaths);
  }

  void _pickVideoFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      _openAddProductWithMedia([video.path]);
    }
  }

  List<String> _asMediaPaths(dynamic result) {
    if (result is! List || result.isEmpty) return const [];
    return result
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _openAddProductFromCamera(dynamic result) {
    _openAddProductWithMedia(_asMediaPaths(result));
  }

  void _openAddProductWithMedia(List<String> mediaFiles) {
    if (mediaFiles.isEmpty || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(mediaFiles: mediaFiles),
      ),
    ).then(_onReturnFromAddProductScreen);
  }

  void _followUser(ItemModel item) async {
    bool? previousFollowing;
    try {
      final currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null) {
        showAppSnackbar(
          context,
          message: _lang == 'ar'
              ? 'يرجى تسجيل الدخول أولاً'
              : 'Please login first',
          type: SnackType.error,
        );
        return;
      }

      if (currentUserId == _sellerUserId(item.seller)) {
        showAppSnackbar(
          context,
          message: _lang == 'ar'
              ? 'لا يمكنك متابعة نفسك'
              : 'Cannot follow yourself',
          type: SnackType.warning,
        );
        return;
      }

      final wasFollowing = item.seller.isFollowing;
      previousFollowing = wasFollowing;
      final targetFollowing = !wasFollowing;

      setState(() {
        _setFollowStateForSeller(item.seller, targetFollowing);
      });

      // Get OneSignal user token
      String? userToken;
      try {
        final subscription = OneSignal.User.pushSubscription;
        userToken = subscription.id;
      } catch (e) {
        print('Error getting OneSignal token: $e');
      }
      final result = await DatabaseService.followUser(
        buyerId: currentUserId,
        userId: _sellerUserId(item.seller),
        userToken: userToken,
      );

      if (result['success'] == true) {
        final confirmedFollowing = result['action'] == 'followed';
        setState(() {
          _setFollowStateForSeller(item.seller, confirmedFollowing);
        });

        String message = _lang == 'ar'
            ? 'تم التحديث بنجاح'
            : 'Updated successfully';
        if (result['action'] == 'followed') {
          message = _lang == 'ar'
              ? 'تمت المتابعة بنجاح'
              : 'Followed successfully';
          ApiService.trackInteraction(currentUserId, item.id, 'follow');
        } else if (result['action'] == 'unfollowed') {
          message = _lang == 'ar' ? 'تم إلغاء المتابعة' : 'Unfollowed';
        }

        showAppSnackbar(context, message: message, type: SnackType.success);

        final user = await FlutterSecureStorage().read(key: 'user_name');
        OneSignalService.sendNotificationToUser(
          playerId: item.seller.token,
          title: "متابعة مشتري",
          message: "$message من قبل $user",
        );
      } else {
        setState(() {
          _setFollowStateForSeller(item.seller, wasFollowing);
        });

        showAppSnackbar(
          context,
          message:
              result['error'] ??
              (_lang == 'ar' ? 'فشل في المتابعة' : 'Follow failed'),
          type: SnackType.error,
        );
      }
    } catch (e) {
      print('Error following user: $e');

      if (previousFollowing != null) {
        setState(() {
          _setFollowStateForSeller(item.seller, previousFollowing!);
        });
      }

      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'حدث خطأ أثناء المتابعة'
            : 'Error following user',
        type: SnackType.error,
      );
    }
  }

  // Show item description with statistics
  void _showItemDescription() async {
    Navigator.pop(context); // Close more options bottom sheet

    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = _sheetIsDark(sheetContext);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.35,
          maxChildSize: 0.6,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: _sheetBackground(sheetContext),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: ApiService.getItemStats(item.id),
              builder: (context, snapshot) {
                final bottomInset =
                    MediaQuery.of(sheetContext).padding.bottom + 16;

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!['success'] != true) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'فشل في تحميل البيانات',
                        style: TextStyle(
                          color: _sheetOnSurface(context),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }

                final stats = snapshot.data!['data'];
                final description = (stats['description'] ?? '')
                    .toString()
                    .trim();
                final hasDescription = description.isNotEmpty;
                final createdAt = stats['created_at']?.toString() ?? '';
                final dateValue = createdAt.isNotEmpty
                    ? createdAt.split(' ').first
                    : '—';

                return ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(bottom: bottomInset),
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white30 : Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            'وصف المنتج',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _sheetOnSurface(context),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: Icon(
                              Iconsax.close_circle,
                              color: isDark ? Colors.white70 : Colors.grey[500],
                              size: 28,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 24,
                      thickness: 0.5,
                      color: Theme.of(context).dividerColor,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Text(
                        hasDescription
                            ? description
                            : 'لا يوجد وصف لهذا المنتج',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: hasDescription
                              ? _sheetOnSurface(context)
                              : (isDark ? Colors.white54 : Colors.grey),
                          fontStyle: hasDescription
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDescriptionStatCard(
                              icon: Iconsax.heart,
                              label: 'الإعجابات',
                              value: _formatCount(stats['likes'] ?? 0),
                              gradientColors: const [
                                Color(0xFFFF8A80),
                                Color(0xFFE57373),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDescriptionStatCard(
                              icon: Iconsax.eye,
                              label: 'المشاهدات',
                              value: _formatCount(stats['views'] ?? 0),
                              gradientColors: const [
                                Color(0xFF81D4FA),
                                Color(0xFF4FC3F7),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDescriptionStatCard(
                              icon: Iconsax.calendar,
                              label: 'تاريخ النشر',
                              value: dateValue,
                              gradientColors: const [
                                Color(0xFFA5D6A7),
                                Color(0xFF66BB6A),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDescriptionStatCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradientColors,
  }) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'غير محدد';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (e) {
      return dateString;
    }
  }

  // Show report options
  void _showReportOptions() async {
    Navigator.pop(context); // Close more options bottom sheet

    _showReasonSelectionSheet(
      title: 'بلغ عن المحتوى',
      subtitle: 'اختر سبب البلاغ',
      confirmLabel: 'تأكيد البلاغ',
      accentColor: Colors.red,
      headerIcon: Iconsax.warning_2,
      reasons: const [
        'محتوى غير لائق',
        'محتوى مضلل',
        'انتهاك حقوق الطبع والنشر',
        'محتوى عنيف',
        'محتوى إباحي',
        'بريد عشوائي',
        'محتوى مخالف للقوانين',
        'تحرش أو تنمر',
        'معلومات شخصية',
        'محتوى مزيف',
        'أخرى',
      ],
      onConfirm: _submitReport,
    );
  }

  void _showReasonSelectionSheet({
    required String title,
    required String subtitle,
    required String confirmLabel,
    required Color accentColor,
    required IconData headerIcon,
    required List<String> reasons,
    required Future<void> Function(String reason) onConfirm,
  }) {
    String? selectedReason;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = _sheetIsDark(context);
            final maxHeight = MediaQuery.of(context).size.height * 0.75;
            final bottomInset = MediaQuery.of(context).padding.bottom;

            return Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: _sheetBackground(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white30 : Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(headerIcon, color: accentColor, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _sheetOnSurface(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: reasons.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).dividerColor,
                        indent: 20,
                        endIndent: 20,
                      ),
                      itemBuilder: (context, index) {
                        final reason = reasons[index];
                        final isSelected = selectedReason == reason;
                        return _buildReasonListItem(
                          label: reason,
                          accentColor: accentColor,
                          isSelected: isSelected,
                          onTap: () {
                            setSheetState(() => selectedReason = reason);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () async {
                                final reason = selectedReason!;
                                Navigator.pop(sheetContext);
                                await onConfirm(reason);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: isDark
                              ? AppColors.darkElevated
                              : Colors.grey[300],
                          disabledForegroundColor: isDark
                              ? Colors.white54
                              : Colors.grey[500],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReasonListItem({
    required String label,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = _sheetIsDark(context);
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.08)
          : _sheetTileBackground(context),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkElevated
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Iconsax.info_circle,
                  size: 20,
                  color: accentColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 16,
                    color: _sheetOnSurface(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Iconsax.tick_circle5,
                  color: AppColors.primary,
                  size: 22,
                )
              else
                const SizedBox(width: 22),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];
    final currentUserId = await AuthService.getCurrentUserId();
    final currentUserName = await AuthService.getCurrentName();

    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'يجب تسجيل الدخول أولاً'
            : 'Please login first',
        type: SnackType.error,
      );
      return;
    }

    try {
      final result = await ApiService.addReport(
        itemId: item.id,
        userId: currentUserId,
        reason: reason,
      );

      if (result['success'] == true) {
        showAppSnackbar(
          context,
          message: _lang == 'ar'
              ? 'تم إرسال البلاغ بنجاح'
              : 'Report sent successfully',
          type: SnackType.success,
        );
        final request = await Dio().post(
          ApiConfigService.instance.sqlEndpoint,
          data: FormData.fromMap({"action": "get_tokens"}),
        );
        List playerIds = request.data['player_ids'];
        List<String> setPlayers = [];
        for (var player_id in playerIds) {
          setPlayers.add(player_id['player_id'].toString());
          await OneSignalServiceWebSys.sendNotificationToMultipleUsers(
            playerIds: setPlayers,
            title: "ابلاغ جديد",
            message: "لديكم إبلاغ جديد من المستخدم $currentUserName",
          );
        }
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? 'فشل في إرسال البلاغ',
          type: SnackType.error,
        );
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: 'حدث خطأ أثناء إرسال البلاغ',
        type: SnackType.error,
      );
    }
  }

  // Show block user options
  void _showBlockUserOptions() async {
    Navigator.pop(context); // Close more options bottom sheet

    _showReasonSelectionSheet(
      title: 'حظر المستخدم',
      subtitle: 'اختر سبب الحظر',
      confirmLabel: 'تأكيد الحظر',
      accentColor: Colors.orange,
      headerIcon: Iconsax.user_remove,
      reasons: const [
        'محتوى مسيء',
        'تحرش',
        'بريد عشوائي',
        'محتوى مزعج',
        'انتهاك الخصوصية',
        'محتوى مخالف',
        'سلوك غير لائق',
        'أخرى',
      ],
      onConfirm: _submitBlockUser,
    );
  }

  Future<void> _submitBlockUser(String reason) async {
    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];
    final currentUserId = await AuthService.getCurrentUserId();

    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'يجب تسجيل الدخول أولاً'
            : 'Please login first',
        type: SnackType.error,
      );
      return;
    }

    try {
      // Use the same report system but with a different reason format
      final result = await ApiService.addReport(
        itemId: item.id,
        userId: currentUserId,
        reason: 'حظر المستخدم: $reason',
      );

      if (result['success'] == true) {
        showAppSnackbar(
          context,
          message: _lang == 'ar'
              ? 'تم إرسال طلب الحظر بنجاح'
              : 'Block request sent',
          type: SnackType.success,
        );
        final request = await Dio().post(
          ApiConfigService.instance.sqlEndpoint,
          data: FormData.fromMap({"action": "get_tokens"}),
        );
        List playerIds = request.data['player_ids'];
        List<String> setPlayers = [];
        for (var player_id in playerIds) {
          setPlayers.add(player_id['player_id'].toString());
          await OneSignalServiceWebSys.sendNotificationToMultipleUsers(
            playerIds: setPlayers,
            title: "حظر مستخدم جديد",
            message: "حظر المستخدم: $reason",
          );
        }
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? 'فشل في إرسال طلب الحظر',
          type: SnackType.error,
        );
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: 'حدث خطأ أثناء إرسال طلب الحظر',
        type: SnackType.error,
      );
    }
  }

  void _handleLike(ItemModel item) async {
    if (!_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'يجب تسجيل الدخول أولاً'
            : 'Please login first',
        type: SnackType.error,
      );
      return;
    }

    try {
      final user = await FlutterSecureStorage().read(key: 'user_name');
      setState(() {
        item.interactions.isLiked = !item.interactions.isLiked;
        if (item.interactions.isLiked) {
          item.interactions.likes++;
          OneSignalService.sendNotificationToUser(
            playerId: item.seller.token,
            title: "إعجاب على المنتج ${item.name}",
            message: "تم الإعجاب من قبل $user",
          );
        } else {
          item.interactions.likes--;
          OneSignalService.sendNotificationToUser(
            playerId: item.seller.token,
            title: "إعجاب على المنتج ${item.name}",
            message: "تم إلغاء الإعجاب من قبل $user",
          );
        }
      });

      _triggerHeartAnimation(item.interactions.isLiked);

      if (item.interactions.isLiked) {
        ApiService.trackInteraction(currentUserId, item.id, 'like');
      }

      // Send request to server
      final result = await ApiService.toggleLike(
        itemId: item.id,
        userId: currentUserId,
      );

      if (result['success'] != true) {
        // Revert changes if server request failed
        setState(() {
          item.interactions.isLiked = !item.interactions.isLiked;
          if (item.interactions.isLiked) {
            item.interactions.likes++;
          } else {
            item.interactions.likes--;
          }
        });

        showAppSnackbar(
          context,
          message: result['error'] ?? 'فشل في تحديث الإعجاب',
          type: SnackType.error,
        );
      }
    } catch (e) {
      // Revert changes if error occurred
      setState(() {
        item.interactions.isLiked = !item.interactions.isLiked;
        if (item.interactions.isLiked) {
          item.interactions.likes++;
        } else {
          item.interactions.likes--;
        }
      });

      showAppSnackbar(
        context,
        message: 'حدث خطأ أثناء تحديث الإعجاب',
        type: SnackType.error,
      );
    }
  }

  void _handleShare(ItemModel item) async {
    try {
      final shareImageUrl = _itemImageUrl(item);
      final response = await http.get(Uri.parse(shareImageUrl));
      final bytes = response.bodyBytes;

      // حفظ الصورة في ملف مؤقت
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/shared_image.png').create();
      await file.writeAsBytes(bytes);

      final box = context.findRenderObject() as RenderBox?;
      String shareText =
          '''
  إسم المنتج:   ${item.name}

  💰 السعر: ${item.price} ريال قطري

  📝 الوصف: ${item.description}

  تسوق الأن على تطبيق MartIt

  ''';
      final user = await FlutterSecureStorage().read(key: 'user_name');
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        subject: 'منتج رائع على MartIt - ${item.name}',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      ).then((_) {
        OneSignalService.sendNotificationToUser(
          playerId: item.seller.token,
          title: "مشاركة جديدة من $user",
          message: "لقد تمت مشاركة منتجك ${item.name} من قبل المستخدم $user",
        );
      });
      setState(() {
        item.interactions.shares++;
      });
      ApiService.trackInteraction(_currentUserId, item.id, 'share');
    } catch (e) {
      showAppSnackbar(
        context,
        message: 'حدث خطأ أثناء المشاركة',
        type: SnackType.error,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _gridScrollController.removeListener(_onGridScroll);
    _gridScrollController.dispose();
    _heartAnimController?.dispose();
    super.dispose();
  }
}

enum _InlineCartVariant { feed, grid }

/// Expanding cart control: collapsed cart/+ icon → pill with − / qty / +.
/// At qty == 1, the first "−" tap morphs into trash; trash removes & collapses.
class _InlineCartControl extends StatefulWidget {
  final int cartQuantity;
  final int stockQuantity;
  final _InlineCartVariant variant;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onNotify;

  const _InlineCartControl({
    required this.cartQuantity,
    required this.stockQuantity,
    required this.variant,
    required this.onAdd,
    required this.onRemove,
    required this.onNotify,
  });

  @override
  State<_InlineCartControl> createState() => _InlineCartControlState();
}

class _InlineCartControlState extends State<_InlineCartControl>
    with SingleTickerProviderStateMixin {
  static const Color _brand = Color(0xFF5C33EA);

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _awaitingDelete = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _bounceAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 60),
        ]).animate(
          CurvedAnimation(
            parent: _bounceController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void didUpdateWidget(covariant _InlineCartControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cartQuantity != 1 && _awaitingDelete) {
      _awaitingDelete = false;
    }
    if (widget.cartQuantity != oldWidget.cartQuantity &&
        widget.cartQuantity > 0) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  bool get _isOutOfStock =>
      widget.cartQuantity == 0 && widget.stockQuantity == 0;

  bool get _expanded => widget.cartQuantity > 0;

  bool get _isFeed => widget.variant == _InlineCartVariant.feed;

  Future<void> _handleAdd() async {
    if (_awaitingDelete) setState(() => _awaitingDelete = false);
    await _bounceController.forward(from: 0);
    widget.onAdd();
  }

  void _handleMinusOrTrash() {
    if (widget.cartQuantity > 1) {
      if (_awaitingDelete) setState(() => _awaitingDelete = false);
      widget.onRemove();
      return;
    }
    if (widget.cartQuantity == 1) {
      if (_awaitingDelete) {
        setState(() => _awaitingDelete = false);
        widget.onRemove();
      } else {
        setState(() => _awaitingDelete = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOutOfStock) {
      return _buildOutOfStock();
    }

    if (_isFeed) {
      return _buildFeedControl();
    }
    return _buildGridControl();
  }

  Widget _buildOutOfStock() {
    return Material(
      color: Colors.grey.shade400,
      borderRadius: BorderRadius.circular(_isFeed ? 14 : 8),
      child: InkWell(
        onTap: widget.onNotify,
        borderRadius: BorderRadius.circular(_isFeed ? 14 : 8),
        child: SizedBox(
          width: _isFeed ? 44 : 32,
          height: _isFeed ? 44 : 32,
          child: Icon(
            Iconsax.notification,
            color: Colors.white,
            size: _isFeed ? 22 : 18,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedControl() {
    // Stay in the side action column: expand vertically, not sideways.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: 46,
      height: _expanded ? 120 : 52,
      decoration: BoxDecoration(
        color: _expanded ? _brand : Colors.transparent,
        borderRadius: BorderRadius.circular(23),
        boxShadow: _expanded
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: _expanded
            ? _buildFeedExpandedColumn(key: const ValueKey('feed_exp'))
            : _buildFeedCollapsed(key: const ValueKey('feed_col')),
      ),
    );
  }

  Widget _buildFeedCollapsed({Key? key}) {
    return KeyedSubtree(
      key: key,
      child: GestureDetector(
        onTap: _handleAdd,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 46,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _bounceAnimation,
                child: const Icon(
                  Iconsax.shopping_cart,
                  color: Colors.white,
                  size: 30,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.cartQuantity}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedExpandedColumn({Key? key}) {
    return KeyedSubtree(
      key: key,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _pillIconButton(icon: Iconsax.add, onTap: _handleAdd),
          ScaleTransition(
            scale: _bounceAnimation,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Text(
                '${widget.cartQuantity}',
                key: ValueKey<int>(widget.cartQuantity),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          _pillIconButton(
            icon: _awaitingDelete ? Iconsax.trash : Iconsax.minus,
            isTrash: _awaitingDelete,
            onTap: _handleMinusOrTrash,
          ),
        ],
      ),
    );
  }

  Widget _buildGridControl() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: 32,
      width: _expanded ? 108 : 32,
      decoration: BoxDecoration(
        color: _brand,
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: _expanded
            ? _buildExpandedRow(key: const ValueKey('grid_exp'))
            : _buildGridCollapsed(key: const ValueKey('grid_col')),
      ),
    );
  }

  Widget _buildExpandedRow({Key? key}) {
    return KeyedSubtree(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _pillIconButton(
              icon: _awaitingDelete ? Iconsax.trash : Iconsax.minus,
              isTrash: _awaitingDelete,
              onTap: _handleMinusOrTrash,
            ),
            ScaleTransition(
              scale: _bounceAnimation,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: Text(
                  '${widget.cartQuantity}',
                  key: ValueKey<int>(widget.cartQuantity),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            _pillIconButton(icon: Iconsax.add, onTap: _handleAdd),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCollapsed({Key? key}) {
    return KeyedSubtree(
      key: key,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleAdd,
          borderRadius: BorderRadius.circular(8),
          child: ScaleTransition(
            scale: _bounceAnimation,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isTrash = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 32,
          height: 32,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Icon(
              icon,
              key: ValueKey<String>('${icon.codePoint}-$isTrash'),
              color: isTrash ? const Color(0xFFFFCDD2) : Colors.white,
              size: isTrash ? 18 : 16,
            ),
          ),
        ),
      ),
    );
  }
}
