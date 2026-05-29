import 'dart:io';
import 'dart:math';

import 'package:BML/core/services/onesignal_service.dart';
import 'package:BML/core/services/onesignal_service_web.dart';
import 'package:BML/features/add_product/add_product_screen.dart';
import 'package:BML/features/auth/login.dart';
import 'package:BML/shared/providers/app_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/database_service.dart';
import '../../core/models/item_model.dart';
import '../../core/utils/product_image_url.dart';
import '../../core/widgets/video_player_widget.dart';
import '../../core/widgets/media_viewer_widget.dart';
import '../auth/login_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';
import '../comments/comments_modal.dart';
import '../camera/camera_screen.dart';
import '../cart/shopping_cart_screen.dart';
import '../chat/conversations_screen.dart';
import '../orders/my_orders_screen.dart';
import '../orders/customer_orders_screen.dart';
import 'package:http/http.dart' as http;

class TikTokFeedScreen extends StatefulWidget {
  final String? initialItemId;

  const TikTokFeedScreen({super.key, this.initialItemId});

  @override
  State<TikTokFeedScreen> createState() => _TikTokFeedScreenState();
}

class _TikTokFeedScreenState extends State<TikTokFeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isLoggedIn = false;
  List<ItemModel> _items = [];
  bool _isLoading = false;
  bool _hasError = false;
  int _currentPage = 0;
  String? _currentItemId;
  String? _currentUserId;
  String? _currentUserRole;
  List<String> _categories = [];
  String?
  _selectedCategory; // ✅ الفلتر الحالي - null = الكل، غير null = تصنيف محدد
  bool _isLoadingCategories = false;
  String? _currentStoreId; // ✅ المتجر الحالي للمنتج المعروض

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
    _checkLoginStatus();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentIndex && page < _items.length) {
      final newStoreId = _items[page].storeid;

      setState(() {
        _currentIndex = page;
        _currentItemId = _items[page].id;
      });

      // ✅ تحديث التصنيفات إذا تغير المتجر
      if (newStoreId != _currentStoreId) {
        _loadCategoriesForStore(newStoreId);
      }
    }
  }

  Future<void> _checkLoginStatus() async {
    final _currentUserIdx = await AuthService.getCurrentUserId();
    final isLoggedIn = await AuthService.isLoggedIn();

    String? userRole;

    if (isLoggedIn && _currentUserIdx != null) {
      try {
        var result = await Dio().get(
          'http://globee-trading.com/app2026/profile.php?user_id=$_currentUserIdx&k=${DateTime.now().millisecondsSinceEpoch}',
          options: Options(headers: {'Content-Type': 'application/json'}),
        );

        // ✅ تحقق إن data و data['data'] مش null قبل ما تجيب الـ role
        if (result.data != null && result.data['data'] != null) {
          final roleFromApi = result.data['data']['role'];
          debugPrint('🔑 User role from API: "$roleFromApi"');
          debugPrint('🔑 Role type: ${roleFromApi.runtimeType}');
          userRole = roleFromApi?.toString();
        }
      } catch (e) {
        print('Error fetching user profile: $e');
        // ✅ لو فيه error في الـ API، الصفحة تكمل بدون role
      }
    }

    debugPrint(
      '🔑 Final _currentUserRole: "$userRole" (${userRole.runtimeType})',
    );

    setState(() {
      _isLoggedIn = isLoggedIn;
      _currentUserId = _currentUserIdx;
      _currentUserRole = userRole; // ✅ هيبقى null لو مش مسجل أو فيه error
    });

    _loadItems(uid: _currentUserId, isRefresh: true);
  }

  Future<void> _loadCategoriesForStore(String storeId) async {
    // ✅ تجنب إعادة التحميل إذا كان نفس المتجر
    if (storeId == _currentStoreId && _categories.isNotEmpty) return;
    if (_isLoadingCategories) return;

    setState(() {
      _isLoadingCategories = true;
    });

    try {
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
  }) async {
    if (_isLoading) return;
    print("SSSSSS $uid");
    print("Category Filter: $category");

    setState(() {
      _isLoading = true;
      _hasError = false;
      if (isRefresh) {
        _currentPage = 0;
        _items.clear();
      }
    });

    try {
      List<ItemModel> items;

      // ✅ نجيب الـ user_id سواء مسجل دخول أو لأ
      final currentUserId = _isLoggedIn
          ? await AuthService.getCurrentUserId()
          : null;

      print("cccccccccc $currentUserId");

      if (_isLoggedIn && currentUserId != null) {
        // ✅ لو مسجل دخول، نستخدم fetchItemsWithLikes
        items = await ApiService.fetchItemsWithLikes(
          userId: currentUserId,
          limit: 10,
          offset: isRefresh ? 0 : _items.length,
          initialItemId: initiItem == "" ? initiItem : widget.initialItemId,
          category: category,
          country: "QA",
        );
      } else {
        // ✅ لو مش مسجل، نستخدم fetchItems عادي (بدون user_id)
        items = await ApiService.fetchItems(
          page: isRefresh ? 0 : _currentPage,
          userId: uid,
          initialItemId: initiItem == "" ? initiItem : widget.initialItemId,
          category: category,
          country: "QA",
        );
      }

      setState(() {
        if (isRefresh) {
          _items = items;
        } else {
          _items.addAll(items);
        }
        _isLoading = false;
        _currentPage++;
      });

      // ✅ تحميل التصنيفات للمتجر الأول بعد تحميل المنتجات
      if (items.isNotEmpty && isRefresh) {
        _loadCategoriesForStore(items[0].storeid);
      }
    } catch (e) {
      print('API Error: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الاتصال بالخادم: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () => _loadItems(
              isRefresh: true,
              uid: _items[0].seller.id,
              category: _selectedCategory,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // تعرض Dialog لتأكيد الخروج
        bool exitApp =
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('تأكيد الخروج'),
                content: Text('هل تريد الخروج من التطبيق؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('لا'),
                  ),
                  TextButton(
                    onPressed: () => SystemNavigator.pop(),
                    child: Text('نعم'),
                  ),
                ],
              ),
            ) ??
            false;

        return exitApp; // لو true، يخرج التطبيق، لو false، يبقى داخل
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isLoading && _items.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.box, size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد منتجات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _loadItems(
                        isRefresh: true,
                        category: _selectedCategory,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  // Video Feed
                  PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    onPageChanged: (index) {
                      // ✅ نحسب الـ actual index باستخدام modulo
                      final actualIndex = index % _items.length;

                      setState(() {
                        _currentIndex = actualIndex;
                      });

                      // ✅ لو وصل لآخر 3 أصناف، نجيب أصناف جديدة مع الفلتر الحالي
                      if (actualIndex >= _items.length - 3 && !_isLoading) {
                        print(
                          '🔄 Loading more items with category: ${_selectedCategory ?? "ALL"}',
                        );
                        _loadItems(
                          uid: _items[actualIndex].seller.id,
                          initiItem: "",
                          category: _selectedCategory, // ✅ نستخدم الفلتر الحالي
                        );
                      }
                    },
                    itemCount: _items.isEmpty
                        ? 0
                        : null, // ✅ null = infinite scroll
                    itemBuilder: (context, index) {
                      if (_items.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      // ✅ نستخدم modulo عشان نعيد تدوير الأصناف
                      final actualIndex = index % _items.length;
                      return _buildVideoItem(_items[actualIndex]);
                    },
                  ),

                  // Top Bar
                  _buildTopBar(),
                  // Categories Bar
                  _buildCategoriesBar(),

                  // Side Actions
                  _buildSideActions(),

                  // Bottom Info
                  _buildBottomInfo(),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Add Product Button
            if (_isLoggedIn)
              Visibility(
                visible: _currentUserRole?.toLowerCase() == 'admin',
                child: IconButton(
                  onPressed: () async {
                    // AuthService.getUserStatus();
                    String? uid = await AuthService.getCurrentUID();
                    if (_isLoggedIn) {
                      AuthService.getUserStatus(uid).then((val) {
                        if (val['status'] == '2') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم حظرك نهائياً من إستخدام التطبيق يرجى التواصل مع الدعم لحل المشكلة!',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } else {
                          _handleAddProduct();
                        }
                      });
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Iconsax.add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            if (!_isLoggedIn)
              IconButton(
                onPressed: () async {
                  // AuthService.getUserStatus();
                  String? uid = await AuthService.getCurrentUID();
                  if (_isLoggedIn) {
                    AuthService.getUserStatus(uid).then((val) {
                      if (val['status'] == '2') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم حظرك نهائياً من إستخدام التطبيق يرجى التواصل مع الدعم لحل المشكلة!',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else {
                        _handleAddProduct();
                      }
                    });
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  }
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.login,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),

            // Actions
            Row(
              children: [
                Stack(
                  children: [
                    Positioned(
                      left: 1,
                      top: 1,
                      child: IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Iconsax.search_normal,
                          color: Colors.black45,
                          size: 28,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SearchScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Iconsax.search_normal,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                if (_isLoggedIn)
                  Stack(
                    children: [
                      Positioned(
                        left: 1,
                        top: 1,
                        child: IconButton(
                          onPressed: _showMoreOptions,
                          icon: const Icon(
                            Iconsax.more,
                            color: Colors.black45,
                            size: 28,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _showMoreOptions,
                        icon: const Icon(
                          Iconsax.more,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesBar() {
    // ✅ إظهار مؤشر تحميل أثناء جلب التصنيفات
    if (_isLoadingCategories) {
      return Positioned(
        top: 100,
        left: 0,
        right: 0,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_categories.isEmpty) return const SizedBox();

    return Positioned(
      top: 120, // تحت الأيقونات العلوية
      left: 0,
      right: 0,
      child: Container(
        height: 50,
        decoration: BoxDecoration(),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length + 1, // +1 للكل
          itemBuilder: (context, index) {
            if (index == 0) {
              // زر "الكل"
              return _buildCategoryChip(
                label: 'الكل',
                isSelected: _selectedCategory == null,
                onTap: () {
                  if (_selectedCategory == null)
                    return; // لو مختار بالفعل، متعملش حاجة

                  setState(() {
                    _selectedCategory = null;
                  });
                  // تحديث قائمة المنتجات - جلب الكل
                  _loadItems(
                    isRefresh: true,
                    uid: _currentUserId,
                    category: null,
                  );
                },
              );
            }

            final category = _categories[index - 1];
            return _buildCategoryChip(
              label: category,
              isSelected: _selectedCategory == category,
              onTap: () {
                if (_selectedCategory == category)
                  return; // لو مختار بالفعل، متعملش حاجة

                setState(() {
                  _selectedCategory = category;
                });
                // تحديث قائمة المنتجات حسب الفئة
                _loadItems(
                  isRefresh: true,
                  uid: _currentUserId,
                  category: category,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withOpacity(0.3),
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
              color: Colors.white,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              shadows: const [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2,
                  color: Colors.black45,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideActions() {
    if (_items.isEmpty || _currentIndex >= _items.length)
      return const SizedBox();

    final item = _items[_currentIndex];
    return Positioned(
      right: 9,
      bottom: 140,
      child: Column(
        children: [
          _buildActionButton(
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.secondary,
              child: item.seller.avatar.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        item.seller.avatar,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // ✅ لو فيه error في الصورة، اعرض الـ Text
                          return Center(
                            child: Text(
                              item.seller.name.isNotEmpty
                                  ? item.seller.name[0]
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          // ✅ أثناء التحميل
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    )
                  : Text(
                      item.seller.name.isNotEmpty ? item.seller.name[0] : 'U',
                      style: const TextStyle(
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

          // Follow Button
          // Follow Button
          if (_isLoggedIn)
            Visibility(
              visible: _currentUserId == item.seller.id ? false : true,
              child: _buildActionButton(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: item.seller.isFollowing
                        ? const Color(0xFF6B7280) // رمادي داكن للمتابع
                        : AppColors.primary, // لون أساسي للغير متابع
                    borderRadius: BorderRadius.circular(20),
                    border: item.seller.isFollowing
                        ? Border.all(color: const Color(0xFF4B5563), width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.seller.isFollowing)
                        const Icon(Icons.check, color: Colors.white, size: 14),
                      if (item.seller.isFollowing) const SizedBox(width: 4),
                      Text(
                        item.seller.isFollowing ? 'يتابع' : 'متابعة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  _followUser(item);
                },
              ),
            ),

          // Like Button
          _buildActionButton(
            child: Column(
              children: [
                Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 1,
                      child: Icon(
                        Iconsax.heart,
                        color: item.interactions.isLiked
                            ? Colors.red
                            : Colors.black45,
                        size: 33,
                      ),
                    ),
                    Icon(
                      item.interactions.isLiked
                          ? Iconsax.heart5
                          : Iconsax.heart,
                      color: item.interactions.isLiked
                          ? Colors.red
                          : Colors.white,
                      size: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCount(item.interactions.likes),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 1,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _handleLike(item),
          ),

          // Comment Button
          _buildActionButton(
            child: Column(
              children: [
                Stack(
                  children: [
                    Positioned(
                      left: 1,
                      top: 1,
                      child: Icon(
                        Iconsax.message,
                        color: Colors.black45,
                        size: 32,
                      ),
                    ),
                    const Icon(Iconsax.message, color: Colors.white, size: 32),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCount(item.interactions.comments),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 1,
                        color: Colors.black,
                      ),
                    ],
                  ),
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

          // Share Button
          _buildActionButton(
            child: Column(
              children: [
                Stack(
                  children: [
                    Positioned(
                      left: 1,
                      top: 1,
                      child: Icon(
                        Iconsax.share,
                        size: 32,
                        color: Colors.black45,
                      ),
                    ),
                    const Icon(Iconsax.share, color: Colors.white, size: 32),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCount(item.interactions.shares),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 1,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _handleShare(item),
          ),

          // Shopping Cart Button
          Visibility(
            visible: _currentUserId == item.seller.id ? false : true,
            child: _buildActionButton(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Positioned(
                        left: 1,
                        top: 1,
                        child: Icon(
                          Iconsax.shopping_cart,
                          size: 32,
                          color: Colors.black45,
                        ),
                      ),
                      const Icon(
                        Iconsax.shopping_cart,
                        color: Colors.white,
                        size: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCount(item.interactions.cartQuantity),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 1,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () => _showCartBottomSheet(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(8), child: child),
    );
  }

  Widget _buildBottomInfo() {
    if (_items.isEmpty || _currentIndex >= _items.length)
      return const SizedBox();

    final item = _items[_currentIndex];

    return Positioned(
      left: 16,
      right: 80,
      bottom: 10,
      child: Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Iconsax.user, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  item.seller.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Product Title
            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Price
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                item.quantity == 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'نفذ من المخزون',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        "${item.quantity} ${item.quantity >= 3 && item.quantity <= 9 ? "Pcs" : "Pc"}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black26,
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

  Widget _buildVideoItem(ItemModel item) {
    final feedUrls = item.feedMediaUrls;
    final imageUrl = feedUrls.isNotEmpty
        ? feedUrls.first
        : ProductImageUrl.albadaaImageUrl(idx: item.idx, id: item.id);
    debugPrint(
      '🖼️ Feed item ${item.id} store=${item.storeid} mediaCount=${feedUrls.length} imageUrl=$imageUrl',
    );

    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black,
        child: MediaViewerWidget(
          mediaUrls: feedUrls.isNotEmpty ? feedUrls : [imageUrl],
          itmId: item.id,
          itmIdx: item.idx,
          storeid: item.storeid,
          autoPlayVideo: true,
          showControls: false,
          showIndicators: feedUrls.length > 1,
        ),
      ),
    );
  }

  void _handleAddProduct() async {
    _showAddProductBottomSheet();
  }

  void _showAddProductBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'إضافة منتج جديد',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Iconsax.camera, color: AppColors.primary),
              title: const Text('إضافة صورة'),
              subtitle: const Text('التقط صورة للمنتج'),
              onTap: () {
                Navigator.pop(context);
                _showImageSourceBottomSheet();
              },
            ),
            ListTile(
              leading: const Icon(
                Iconsax.video_play,
                color: AppColors.secondary,
              ),
              title: const Text('إضافة فيديو'),
              subtitle: const Text('سجل فيديو للمنتج'),
              onTap: () {
                Navigator.pop(context);
                _showVideoSourceBottomSheet();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('المزيد', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              _buildMoreOption(
                Iconsax.user,
                'عرض الملف الشخصي',
                _showCurrentUserProfile,
              ),
              _buildMoreOption(
                Iconsax.bag_2,
                'طلبات العملاء',
                _showCustomerOrders,
              ),
              _buildMoreOption(Iconsax.shopping_bag, 'طلباتي', _showMyOrders),
              _buildMoreOption(
                Iconsax.shopping_cart,
                'عرض سلة التسوق',
                _showShoppingCart,
              ),
              _buildMoreOption(
                Iconsax.message,
                'المحادثات',
                _showConversations,
              ),
              _buildMoreOption(
                Iconsax.document_text,
                'الوصف',
                _showItemDescription,
              ),
              _buildMoreOption(
                Iconsax.warning_2,
                'بلغ عن المحتوى',
                _showReportOptions,
              ),
              _buildMoreOption(
                Iconsax.user_remove,
                'حظر المستخدم',
                _showBlockUserOptions,
              ),
              _buildMoreOption(Iconsax.logout, 'تسجيل الخروج', _handleLogout),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _showShoppingCart() async {
    Navigator.pop(context); // Close bottom sheet

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShoppingCartScreen(userId: currentUserId),
      ),
    );
  }

  void _showConversations() async {
    Navigator.pop(context); // Close bottom sheet

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
    );
  }

  void _handleLogout() async {
    Navigator.pop(context);
    await GoogleSignIn.instance.disconnect();
    await GoogleSignIn.instance.signOut();
    await AuthService.logout();
    setState(() {
      _isLoggedIn = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تسجيل الخروج بنجاح')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على بيانات المستخدم'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('إضافة صورة', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Iconsax.camera, color: AppColors.primary),
              title: const Text('التقاط صورة'),
              subtitle: const Text('استخدم الكاميرا لالتقاط صورة جديدة'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScreen(isVideo: false),
                  ),
                ).then((result) async {
                  if (result != null &&
                      result is List<String> &&
                      result.isNotEmpty) {
                    // Create new item first
                    final userId = await AuthService.getCurrentUserId();
                    if (userId != null) {
                      final createResult = await DatabaseService.createItem(
                        userId,
                      );
                      if (createResult['success'] == true) {
                        final itemId = createResult['item_id'].toString();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddProductScreen(
                              mediaFiles: result,
                              itemId: itemId,
                            ),
                          ),
                        );
                      }
                    }
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery, color: AppColors.secondary),
              title: const Text('اختيار من المعرض'),
              subtitle: const Text('اختر صورة من معرض الصور'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showVideoSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('إضافة فيديو', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Iconsax.video_circle,
                color: AppColors.primary,
              ),
              title: const Text('تسجيل فيديو'),
              subtitle: const Text('استخدم الكاميرا لتسجيل فيديو جديد'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScreen(isVideo: true),
                  ),
                ).then((result) async {
                  if (result != null &&
                      result is List<String> &&
                      result.isNotEmpty) {
                    // Create new item first
                    final userId = await AuthService.getCurrentUserId();
                    if (userId != null) {
                      final createResult = await DatabaseService.createItem(
                        userId,
                      );
                      if (createResult['success'] == true) {
                        final itemId = createResult['item_id'].toString();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddProductScreen(
                              mediaFiles: result,
                              itemId: itemId,
                            ),
                          ),
                        );
                      }
                    }
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(
                Iconsax.video_play,
                color: AppColors.secondary,
              ),
              title: const Text('اختيار من المعرض'),
              subtitle: const Text('اختر فيديو من معرض الفيديوهات'),
              onTap: () {
                Navigator.pop(context);
                _pickVideoFromGallery();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    await picker.pickMultiImage().then((result) async {
      // Create new item first
      final List<String> imagePaths = result
          .map((image) => image.path)
          .toList();
      print(imagePaths);
      var procx = Provider.of<AppProvider>(context, listen: false);
      procx.allMedia.addAll(imagePaths);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddProductScreen(mediaFiles: []),
        ),
      );
    });
  }

  void _pickVideoFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddProductScreen(mediaFiles: [video.path]),
        ),
      );
    }
  }

  void _followUser(ItemModel item) async {
    try {
      final currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (currentUserId == item.seller.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكنك متابعة نفسك'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ✅ حدّث الـ UI فوراً
      setState(() {
        // ✅ حدّث كل الأصناف لنفس البائع
        for (var i = 0; i < _items.length; i++) {
          if (_items[i].seller.id == item.seller.id) {
            // ✅ اعمل ItemModel جديد بالكامل
            _items[i] = ItemModel(
              id: _items[i].id,
              idx: _items[i].idx,
              storeid: _items[i].storeid,
              name: _items[i].name,
              price: _items[i].price,
              quantity: _items[i].quantity,
              description: _items[i].description,
              views: _items[i].views,
              media: _items[i].media,
              seller: SellerModel(
                // ✅ استخدم SellerModel
                id: _items[i].seller.id,
                uid: _items[i].seller.uid,
                name: _items[i].seller.name,
                avatar: _items[i].seller.avatar,
                token: _items[i].seller.token,
                isFollowing: !_items[i].seller.isFollowing,
              ),
              interactions: _items[i].interactions,
            );
          }
        }
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
        userId: item.seller.id,
        userToken: userToken,
      );

      if (result['success'] == true) {
        // تحديد الرسالة حسب الإجراء الفعلي من السيرفر
        String message = 'تم التحديث بنجاح';
        if (result['action'] == 'followed') {
          message = 'تمت المتابعة بنجاح';
        } else if (result['action'] == 'unfollowed') {
          message = 'تم إلغاء المتابعة';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        final user = await FlutterSecureStorage().read(key: 'user_name');
        OneSignalService.sendNotificationToUser(
          playerId: item.seller.token,
          title: "متابعة مشتري",
          message: "$message من قبل $user",
        );
      } else {
        // ✅ لو فشل، ارجع الحالة زي ما كانت
        setState(() {
          for (var i = 0; i < _items.length; i++) {
            if (_items[i].seller.id == item.seller.id) {
              _items[i] = ItemModel(
                id: _items[i].id,
                idx: _items[i].idx,
                storeid: _items[i].storeid,
                name: _items[i].name,
                price: _items[i].price,
                quantity: _items[i].quantity,
                description: _items[i].description,
                views: _items[i].views,
                media: _items[i].media,
                seller: SellerModel(
                  id: _items[i].seller.id,
                  uid: _items[i].seller.uid,
                  name: _items[i].seller.name,
                  avatar: _items[i].seller.avatar,
                  token: _items[i].seller.token,
                  isFollowing: !_items[i].seller.isFollowing,
                ),
                interactions: _items[i].interactions,
              );
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'فشل في المتابعة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error following user: $e');

      // ✅ لو حصل error، ارجع الحالة
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          if (_items[i].seller.id == item.seller.id) {
            _items[i] = ItemModel(
              id: _items[i].id,
              idx: _items[i].idx,
              storeid: _items[i].storeid,
              name: _items[i].name,
              price: _items[i].price,
              quantity: _items[i].quantity,
              description: _items[i].description,
              views: _items[i].views,
              media: _items[i].media,
              seller: SellerModel(
                id: _items[i].seller.id,
                uid: _items[i].seller.uid,
                name: _items[i].seller.name,
                avatar: _items[i].seller.avatar,
                token: _items[i].seller.token,
                isFollowing: !_items[i].seller.isFollowing,
              ),
              interactions: _items[i].interactions,
            );
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء المتابعة'),
          backgroundColor: Colors.red,
        ),
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
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 4,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2)),
            ),

            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: ApiService.getItemStats(item.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!['success'] != true) {
                    return const Center(
                      child: Text(
                        'فشل في تحميل البيانات',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final stats = snapshot.data!['data'];

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        const Text(
                          'وصف المنتج',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Description
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: Text(
                            stats['description'] ?? 'لا يوجد وصف متاح',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Divider
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primary.withOpacity(0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Statistics
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Iconsax.heart,
                                title: 'الإعجابات',
                                value: _formatCount(stats['likes'] ?? 0),
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: _buildStatCard(
                                icon: Iconsax.eye,
                                title: 'المشاهدات',
                                value: _formatCount(stats['views'] ?? 0),
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(width: 2),
                            Expanded(
                              child: _buildStatCard(
                                icon: Iconsax.calendar,
                                title: 'تاريخ النشر',
                                value: stats['created_at'].toString().split(
                                  ' ',
                                )[0],
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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

    final reportReasons = [
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
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              // Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)
              Color(0xFFD4D4F0),
              Color(0xFFC8D4F5),
              Color(0xFFB4D4F0),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                // color: Colors.white.withOpacity(0.3),
                color: const Color(0xFF1A1A2E).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Title
            const Text(
              'بلغ عن المحتوى',
              style: TextStyle(
                // color: Colors.white,
                color: Color(0xFF1A1A2E),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'اختر سبب البلاغ',
              style: TextStyle(
                // color: Colors.white.withOpacity(0.7),
                color: const Color(0xFF1A1A2E).withOpacity(0.7),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: reportReasons.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      // color: Colors.white.withOpacity(0.1),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        // color: Colors.white.withOpacity(0.2),
                        color: Colors.red.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Iconsax.warning_2,
                        color: Colors.red.withOpacity(0.8),
                      ),
                      title: Text(
                        reportReasons[index],
                        style: const TextStyle(
                          // color: Colors.white,
                          color: Color(0xFF1A1A2E),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () => _submitReport(reportReasons[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport(String reason) async {
    Navigator.pop(context); // Close report options

    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];
    final currentUserId = await AuthService.getCurrentUserId();
    final currentUserName = await AuthService.getCurrentName();

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال البلاغ بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        final request = await Dio().post(
          "https://www.Globee-Trading.com/app2026/sql.php",
          data: FormData.fromMap({"action": "get_tokens"}),
        );
        List player_ids = request.data['player_ids'];
        List<String> setPlayers = [];
        for (var player_id in player_ids) {
          setPlayers.add(player_id['player_id'].toString());
          await OneSignalServiceWebSys.sendNotificationToMultipleUsers(
            playerIds: setPlayers,
            title: "ابلاغ جديد",
            message: "لديكم إبلاغ جديد من المستخدم $currentUserName",
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'فشل في إرسال البلاغ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء إرسال البلاغ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show block user options
  void _showBlockUserOptions() async {
    Navigator.pop(context); // Close more options bottom sheet

    final blockReasons = [
      'محتوى مسيء',
      'تحرش',
      'بريد عشوائي',
      'محتوى مزعج',
      'انتهاك الخصوصية',
      'محتوى مخالف',
      'سلوك غير لائق',
      'أخرى',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              // Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)
              Color(0xFFD4D4F0),
              Color(0xFFC8D4F5),
              Color(0xFFB4D4F0),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                // color: Colors.white.withOpacity(0.3),
                color: const Color(0xFF1A1A2E).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Title
            const Text(
              'حظر المستخدم',
              style: TextStyle(
                // color: Colors.white,
                color: Color(0xFF1A1A2E),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'اختر سبب الحظر',
              style: TextStyle(
                // color: Colors.white.withOpacity(0.7),
                color: const Color(0xFF1A1A2E).withOpacity(0.7),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: blockReasons.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      // color: Colors.white.withOpacity(0.1),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        // color: Colors.white.withOpacity(0.2),
                        color: Colors.orange.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Iconsax.user_remove,
                        color: Colors.orange.withOpacity(0.8),
                      ),
                      title: Text(
                        blockReasons[index],
                        style: const TextStyle(
                          // color: Colors.white,
                          color: Color(0xFF1A1A2E),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () => _submitBlockUser(blockReasons[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitBlockUser(String reason) async {
    Navigator.pop(context); // Close block options

    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];
    final currentUserId = await AuthService.getCurrentUserId();

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الحظر بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        final request = await Dio().post(
          "https://www.Globee-Trading.com/app2026/sql.php",
          data: FormData.fromMap({"action": "get_tokens"}),
        );
        List player_ids = request.data['player_ids'];
        List<String> setPlayers = [];
        for (var player_id in player_ids) {
          setPlayers.add(player_id['player_id'].toString());
          await OneSignalServiceWebSys.sendNotificationToMultipleUsers(
            playerIds: setPlayers,
            title: "حظر مستخدم جديد",
            message: "حظر المستخدم: $reason",
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'فشل في إرسال طلب الحظر'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء إرسال طلب الحظر'),
          backgroundColor: Colors.red,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'فشل في تحديث الإعجاب'),
            backgroundColor: Colors.red,
          ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء تحديث الإعجاب'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleShare(ItemModel item) async {
    try {
      final response = await http.get(Uri.parse(item.primaryImageUrl));
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

  تسوق الأن على تطبيق GlobalFarm

  ''';
      final user = await FlutterSecureStorage().read(key: 'user_name');
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        subject: 'منتج رائع على GlobalFarm - ${item.name}',
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء المشاركة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCartBottomSheet(ItemModel item) async {
    bool isAdded = false;
    if (!_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ جيب الكمية الحالية من السيرفر قبل ما تفتح الـ sheet
    try {
      final result = await ApiService.getCartQuantity(
        itemId: item.id,
        userId: currentUserId,
      );

      if (result['success'] == true) {
        final itemIndex = _items.indexWhere((i) => i.id == item.id);
        if (itemIndex != -1) {
          setState(() {
            _items[itemIndex].interactions.cartQuantity =
                result['quantity'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error loading cart quantity: $e');
    }

    final thumbnail = item.primaryImageUrl;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              // decoration: const BoxDecoration(
              //   gradient: LinearGradient(
              //     begin: Alignment.topCenter,
              //     end: Alignment.bottomCenter,
              //     colors: [
              //       Color(0xFF1A1A2E),
              //       Color(0xFF16213E),
              //       Color(0xFF0F3460),
              //     ],
              //   ),
              //   borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              // ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFD4D4F0),
                    Color(0xFFC8D4F5),
                    Color(0xFFB4D4F0),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'إضافة إلى السلة',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Product info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Product image
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: thumbnail != ''
                                ? Image.network(
                                    thumbnail,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Iconsax.image,
                                          color: Colors.grey,
                                          size: 40,
                                        ),
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.primary,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          );
                                        },
                                  )
                                : Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Iconsax.image,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Product details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${item.price} ريال قطري',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  // Quantity controls
                  _CartQuantityWidget(
                    itemId: item.id,
                    userId: currentUserId,
                    qtt: item.quantity,
                    onQuantityChanged: (newQuantity) {
                      final itemIndex = _items.indexWhere(
                        (i) => i.id == item.id,
                      );
                      if (itemIndex != -1) {
                        setState(() {
                          _items[itemIndex].interactions.cartQuantity =
                              newQuantity;
                        });
                      }
                      setModalState(() {});
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }
}

// ✅ Widget السلة
class _CartQuantityWidget extends StatefulWidget {
  final String itemId;
  final String userId;
  final int qtt;
  final Function(int) onQuantityChanged;

  const _CartQuantityWidget({
    required this.itemId,
    required this.userId,
    required this.qtt,
    required this.onQuantityChanged,
  });

  @override
  State<_CartQuantityWidget> createState() => _CartQuantityWidgetState();
}

class _CartQuantityWidgetState extends State<_CartQuantityWidget> {
  int _currentQuantity = 0;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool isAdded = false;
  @override
  void initState() {
    super.initState();
    _loadQuantity();
  }

  Future<void> _loadQuantity() async {
    try {
      final result = await ApiService.getCartQuantity(
        itemId: widget.itemId,
        userId: widget.userId,
      );

      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            _currentQuantity = result['quantity'] ?? 0;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading quantity: $e');
      if (mounted) {
        setState(() {
          _currentQuantity = 0;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(bool increase) async {
    if (_isUpdating) return;

    // ✅ شيك على الكمية قبل ما نبعت للسيرفر
    if (increase && _currentQuantity >= widget.qtt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الكمية المتاحة: ${widget.qtt} فقط'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!increase && _currentQuantity <= 0) {
      print('❌ Cannot decrease: quantity is already 0');
      return;
    }

    print('🔄 Updating quantity: ${increase ? "increase" : "decrease"}');

    setState(() {
      _isUpdating = true;
    });

    try {
      Map<String, dynamic> result;

      if (increase) {
        result = await ApiService.addToCart(
          itemId: widget.itemId,
          userId: widget.userId,
          quantity: 1,
        );
      } else {
        print('📤 Calling removeFromCart API'); // ← Debug
        result = await ApiService.removeFromCart(
          itemId: widget.itemId,
          userId: widget.userId,
        );
        print('📥 Remove API response: $result'); // ← Debug
      }

      if (result['success'] == true) {
        print(
          '✅ API Success! New quantity from server: ${result['quantity']}',
        ); // ← Debug

        if (mounted) {
          setState(() {
            // ✅ استخدم الكمية اللي جاية من السيرفر
            if (result['quantity'] != null) {
              _currentQuantity = result['quantity'];
              print('✅ Updated _currentQuantity to: $_currentQuantity');
              if (_currentQuantity == 0) {
                setState(() {
                  isAdded = false;
                });
              }
            } else {
              // Fallback
              if (increase) {
                _currentQuantity++;
              } else {
                if (_currentQuantity > 0) _currentQuantity--;
              }
            }
            _isUpdating = false;
          });
          widget.onQuantityChanged(_currentQuantity);
        }
      } else {
        print('❌ API Failed: ${result['error']}'); // ← Debug

        // ✅ لو السيرفر رفض بسبب الكمية
        if (mounted) {
          setState(() {
            _isUpdating = false;
          });

          String errorMessage = result['error'] ?? 'حدث خطأ';

          // ✅ لو في معلومات عن الكمية المتاحة
          if (result['available_quantity'] != null) {
            errorMessage =
                'الكمية المتاحة: ${result['available_quantity']} فقط';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('💥 Exception occurred: $e'); // ← Debug

      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ في الاتصال'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // ✅ متغير يحدد إذا وصلنا للحد الأقصى
    final bool isMaxQuantity = _currentQuantity >= widget.qtt;

    return Column(
      children: [
        const SizedBox(height: 20),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // زر النقصان
              GestureDetector(
                onTap: _isUpdating || _currentQuantity <= 0
                    ? null
                    : () => _updateQuantity(false),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isUpdating
                        ? Colors.grey.withOpacity(0.3)
                        : _currentQuantity > 0
                        ? Colors.red.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: _isUpdating
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(
                          Iconsax.minus,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),

              const SizedBox(width: 30),

              // عرض الكمية
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Text(
                  _currentQuantity.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 30),

              // زر الزيادة
              GestureDetector(
                onTap: _isUpdating || isMaxQuantity
                    ? null
                    : () {
                        _updateQuantity(true);
                        setState(() {
                          isAdded = true;
                        });
                      },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isUpdating
                        ? Colors.grey.withOpacity(0.3)
                        : isMaxQuantity
                        ? Colors.grey.withOpacity(
                            0.3,
                          ) // ✅ disable لو وصل للحد الأقصى
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: _isUpdating
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Icon(
                          Iconsax.add,
                          color: isMaxQuantity
                              ? Colors.white.withOpacity(0.5)
                              : Colors.white,
                          size: 24,
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => isAdded
              ? Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ShoppingCartScreen(userId: widget.userId),
                  ),
                )
              : Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: Text(
            isAdded ? 'الذهاب إلى السلة' : 'تم',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
