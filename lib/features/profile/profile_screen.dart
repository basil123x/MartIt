import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/models/item_model.dart';
import '../../core/widgets/media_viewer_widget.dart';
import '../../core/widgets/smart_avatar_widget.dart';
import '../../core/utils/theme_extensions.dart';
import '../settings/settings_screen.dart';
import '../product/product_detail_screen.dart';
import 'profile_avatar_preview_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfileModel? _profile;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isLoadingItems = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasErrorItems = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _pageSize = 20;
  String _selectedFilter = '';
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;
  int _avatarCacheTimestamp = DateTime.now().millisecondsSinceEpoch;

  void _bumpAvatarCache() {
    _avatarCacheTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  List<String> get _filters {
    final lang = LocalizationService.instance.currentLanguage;
    return lang == 'ar'
        ? ['الرائجة', 'الأحدث', 'الأقدم']
        : ['Trending', 'Newest', 'Oldest'];
  }

  @override
  void initState() {
    super.initState();
    _selectedFilter = _filters.first;
    _bumpAvatarCache();
    _loadProfile();
    _loadFreshUserDetails();
    _scrollController.addListener(_onScroll);
  }

  String get _itemsOwnerUid =>
      (_profile?.uid.isNotEmpty == true) ? _profile!.uid : widget.userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(_bumpAvatarCache);
    _loadFreshUserDetails();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isCollapsed = _scrollController.hasClients &&
        _scrollController.offset > (300 - kToolbarHeight);
    if (isCollapsed != _isCollapsed) {
      setState(() => _isCollapsed = isCollapsed);
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreItems();
      }
    }
  }

  String _getSortParam() {
    switch (_selectedFilter) {
      case 'الأحدث':
      case 'Newest':
        return 'newest';
      case 'الأقدم':
      case 'Oldest':
        return 'oldest';
      case 'الرائجة':
      case 'Trending':
      default:
        return 'views';
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('🔍 Loading profile for userId: ${widget.userId}');

      final response = await ApiService.getUserProfile(widget.userId);

      print('🔍 Profile response: $response');

      if (response['success'] == true) {
        setState(() {
          _profile = UserProfileModel.fromJson(response['data']);
          _isLoading = false;
          _bumpAvatarCache();
        });
        await _loadFreshUserDetails();
        _loadItems();
      } else {
        print('❌ Profile error: ${response['error']}');
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Profile exception: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFreshUserDetails() async {
    final currentUid = await AuthService.getCurrentUID();
    if (currentUid == null || currentUid != widget.userId) return;

    const storage = FlutterSecureStorage();
    final email =
        await storage.read(key: "user_email") ??
        await storage.read(key: "social_email");
    if (email == null || email.isEmpty) return;

    try {
      final response = await Dio().post(
        "${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
        data: FormData.fromMap({
          "action": "get_user_details",
          "email": email,
        }),
      );

      if (response.data["success"] != true || response.data["data"] == null) {
        return;
      }

      final data = response.data["data"] as Map<String, dynamic>;
      final name = data["name"]?.toString() ?? "";
      if (name.isEmpty) return;

      await AuthService.updateUserName(name);

      if (!mounted) return;
      setState(() {
        if (_profile != null) {
          _profile = UserProfileModel(
            id: _profile!.id,
            uid: _profile!.uid,
            name: name,
            phone: data["phone"]?.toString() ?? _profile!.phone,
            avatar: _profile!.avatar,
            type: _profile!.type,
            itemsCount: _profile!.itemsCount,
          );
        }
      });
    } catch (e) {
      print("Failed to refresh profile name: $e");
    }
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoadingItems = true;
      _hasErrorItems = false;
      _currentOffset = 0;
      _items = [];
    });

    try {
      final response = await ApiService.getUserProfileItems(
        _itemsOwnerUid,
        limit: _pageSize,
        offset: 0,
        sort: _getSortParam(),
      );

      if (response['success'] == true) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(response['data'] ?? []);
          _hasMore = response['hasMore'] ?? false;
          _currentOffset = _pageSize;
          _isLoadingItems = false;
        });
      } else {
        setState(() {
          _hasErrorItems = true;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasErrorItems = true;
        _isLoadingItems = false;
      });
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await ApiService.getUserProfileItems(
        _itemsOwnerUid,
        limit: _pageSize,
        offset: _currentOffset,
        sort: _getSortParam(),
      );

      if (response['success'] == true) {
        final newItems = List<Map<String, dynamic>>.from(response['data'] ?? []);
        setState(() {
          _items.addAll(newItems);
          _hasMore = response['hasMore'] ?? false;
          _currentOffset += _pageSize;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
    });
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _hasError
          ? _buildErrorState()
          : _buildProfileContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.warning_2, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'حدث خطأ في تحميل الملف الشخصي',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _loadProfile();
              _loadItems();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    if (_profile == null) return const SizedBox();

    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: CustomScrollView(
      controller: _scrollController,
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 300,
          floating: false,
          pinned: true,
          centerTitle: true,
          backgroundColor: context.appSurface,
          elevation: 1,
          forceElevated: true,
          title: AnimatedOpacity(
            opacity: _isCollapsed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _profile == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: SmartAvatarWidget(
                          userId: _profile!.uid.isNotEmpty
                              ? _profile!.uid
                              : widget.userId,
                          name: _profile!.name,
                          size: 28,
                          cacheTimestamp: _avatarCacheTimestamp,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _profile!.name,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
          leading: FutureBuilder<String?>(
            future: AuthService.getCurrentUserId(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == widget.userId) {
                return IconButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(profile: _profile),
                      ),
                    );
                    if (result != null && result is Map<String, dynamic>) {
                      if (result['success'] == true) {
                        setState(() {
                          _bumpAvatarCache();
                          if (_profile != null) {
                            _profile = UserProfileModel(
                              id: _profile!.id,
                              uid: _profile!.uid,
                              name: result['name'] ?? _profile!.name,
                              phone: result['phone'] ?? _profile!.phone,
                              avatar: result['avatar'] ?? _profile!.avatar,
                              type: _profile!.type,
                              itemsCount: _profile!.itemsCount,
                            );
                          }
                        });
                        _loadProfile();
                        _loadFreshUserDetails();
                      }
                    } else if (result == true) {
                      setState(() => _bumpAvatarCache());
                      _loadProfile();
                      _loadFreshUserDetails();
                    }
                  },
                  icon: const Icon(Iconsax.setting_2, color: AppColors.primary),
                );
              }
              return const SizedBox();
            },
          ),
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Iconsax.arrow_right_3, color: AppColors.primary),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: context.bottomBarGradient(),
              ),
              child: _buildProfileHeader(),
            ),
          ),
        ),

        // Filter Buttons
        SliverToBoxAdapter(child: _buildFilterButtons()),

        // Profile Items Grid
        SliverToBoxAdapter(child: _buildItemsSection()),
      ],
      ),
    );
  }

  static const _avatarHeroTag = "profile_avatar";

  Future<void> _openAvatarPreview({
    required String userId,
    required bool isOwnProfile,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ProfileAvatarPreviewScreen(
          userId: userId,
          name: _profile?.name ?? "",
          loadSocialFromStorage: isOwnProfile,
          fallbackUrl: _profile?.avatar.isNotEmpty == true ? _profile!.avatar : null,
          cacheTimestamp: _avatarCacheTimestamp,
          heroTag: _avatarHeroTag,
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final userId =
        _profile!.uid.isNotEmpty ? _profile!.uid : widget.userId;
    print('Avatar userId: ${_profile!.uid}');

    return FutureBuilder<String?>(
      future: AuthService.getCurrentUID(),
      builder: (context, snapshot) {
        final isOwnProfile =
            snapshot.hasData && snapshot.data == widget.userId;

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => _openAvatarPreview(
                  userId: userId,
                  isOwnProfile: isOwnProfile,
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SmartAvatarWidget(
                    userId: userId,
                    name: _profile!.name,
                    size: 112,
                    cacheTimestamp: _avatarCacheTimestamp,
                    loadSocialFromStorage: isOwnProfile,
                    fallbackUrl: _profile!.avatar.isNotEmpty ? _profile!.avatar : null,
                    heroTag: _avatarHeroTag,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _profile!.name,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_profile!.itemsCount} منتج',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () => _onFilterChanged(filter),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? AppColors.primary
                      : (context.isDarkMode
                          ? AppColors.darkElevated
                          : context.appSurfaceVariant),
                  foregroundColor: isSelected
                      ? Colors.white
                      : context.appTextPrimary,
                  elevation: isSelected ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  filter,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        children: [
          // Skeleton Loading
          if (_isLoadingItems)
            _buildSkeletonGrid()
          // Empty State
          else if (_items.isEmpty && !_hasErrorItems)
            _buildEmptyState()
          // Error State
          else if (_hasErrorItems)
            _buildItemsErrorState()
          // Items Grid
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductDetailScreen(item: _items[index]),
                    ),
                  ),
                  child: ProfileItemCard(item: _items[index]),
                );
              },
            ),

          // Loading More Indicator
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _buildSkeletonCard();
      },
    );
  }

  Widget _buildSkeletonCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[300]!,
      highlightColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey[100]!,
      child: Card(
        elevation: 0,
        color: isDark ? AppColors.darkSurface : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevated : Colors.grey[300],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkElevated : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkElevated : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.box_1,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد منتجات بعد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بإضافة منتجاتك الآن',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.warning_2,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'فشل في تحميل المنتجات',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadItems,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const ProfileItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.isDarkMode
          ? AppColors.darkSurface
          : const Color(0xFFB4D4F0).withAlpha(40),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: MediaViewerWidget(
                mediaUrls: const [],
                itmId: "${item["id"] ?? ""}",
                itmIdx: "${item["idx"] ?? ""}",
                storeid: "${item["storeid"] ?? item["store_id"] ?? "1"}",
                autoPlayVideo: false,
                showControls: false,
                showIndicators: false,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item['name'] ?? 'غير متوفر',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['price']} ريال',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Iconsax.eye, size: 12, color: Colors.grey),
                      Text(
                        item['views']?.toString() ?? "0",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
