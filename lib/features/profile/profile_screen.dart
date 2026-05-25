import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/item_model.dart';
import '../../core/utils/product_image_url.dart';
import 'edit_profile_screen.dart';

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
  String _selectedFilter = 'الرائجة';
  final List<String> _filters = ['الرائجة', 'الأحدث', 'الأقدم'];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadItems();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreItems();
      }
    }
  }

  String _getSortParam() {
    switch (_selectedFilter) {
      case 'الأحدث':
        return 'newest';
      case 'الأقدم':
        return 'oldest';
      case 'الرائجة':
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
      final response = await ApiService.getUserProfile(
        int.parse(widget.userId),
      );

      if (response['success'] == true) {
        setState(() {
          _profile = UserProfileModel.fromJson(response['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
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
        int.parse(widget.userId),
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
        int.parse(widget.userId),
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
      backgroundColor: Colors.white,
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

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 300,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.primary,
          leading: FutureBuilder<String?>(
            future: AuthService.getCurrentUserId(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == widget.userId) {
                return IconButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(
                          currentName: _profile?.name ?? '',
                          currentPhone: _profile?.phone ?? '',
                          currentType: _profile?.type ?? '',
                          currentAvatar: _profile?.avatar ?? '',
                          currentUid: _profile?.uid ?? '',
                        ),
                      ),
                    );
                    if (result != null && result is Map<String, dynamic>) {
                      if (result['success'] == true) {
                        setState(() {
                          if (_profile != null) {
                            _profile = UserProfileModel(
                              id: _profile!.id,
                              uid: _profile!.uid,
                              name: result['name'] ?? _profile!.name,
                              phone: result['phone'] ?? _profile!.phone,
                              avatar: result['avatar'] ?? _profile!.avatar,
                              type: _profile!.type,
                              itemsCount: _profile!.itemsCount,
                              role: _profile!.role
                            );
                          }
                        });
                        _loadProfile();
                      }
                    } else if (result == true) {
                      _loadProfile();
                    }
                  },
                  icon: const Icon(Iconsax.edit, color: AppColors.primary),
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
              ),
              child: _buildProfileHeader(),
            ),
          ),
        ),

        // Filter Buttons
        if (_profile?.role != '')
        SliverToBoxAdapter(child: _buildFilterButtons()),
        if (_profile?.role != '')
        SliverToBoxAdapter(child: _buildItemsSection()),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Profile Avatar
          Container(
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
            child: CircleAvatar(
              radius: 56,
              backgroundImage: NetworkImage(
                "https://globee.b-cdn.net/users/${_profile?.uid}/1.jpg?k=${DateTime.now().millisecondsSinceEpoch}",
              ),
              backgroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          // User Name
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
          // Items Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      : Colors.grey[200],
                  foregroundColor: isSelected ? Colors.white : Colors.black,
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
      padding: const EdgeInsets.all(16),
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
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return ProfileItemCard(item: _items[index]);
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
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image placeholder
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
              ),
            ),
            // Text placeholders
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
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
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

// Cache عشان منكررش الـ call لو الـ widget اتبنى تاني
final Map<String, Future<List<String>>> _mediaCache = {};

class ProfileItemCard extends StatefulWidget {
  final Map<String, dynamic> item;

  const ProfileItemCard({super.key, required this.item});

  @override
  State<ProfileItemCard> createState() => _ProfileItemCardState();
}

class _ProfileItemCardState extends State<ProfileItemCard> {
  int _currentIndex = 0;
  late Future<List<String>> _mediaFuture;

  @override
  void initState() {
    super.initState();
    final itemId = widget.item['id'].toString();
    final itemIdx = (widget.item['idx'] ?? '').toString();
    final storeId =
        (widget.item['storeid'] ?? widget.item['store_id'] ?? '4').toString();
    final mediaField = widget.item['media']?.toString();
    _mediaFuture = _mediaCache.putIfAbsent(
      '${storeId}_${itemIdx}_$itemId',
      () async => ProductImageUrl.mediaList(
        storeId: storeId,
        itemId: itemId,
        itemIdx: itemIdx,
        mediaField: mediaField,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFB4D4F0).withAlpha(40),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: FutureBuilder<List<String>>(
              future: _mediaFuture,
              builder: (context, snapshot) {
                // ── Loading ──
                if (snapshot.connectionState != ConnectionState.done) {
                  return const ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }

                final mediaList = snapshot.data ?? [];
                print(mediaList);

                // ── No media ──
                if (mediaList.isEmpty) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  );
                }

                // ── Slider ──
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: PageView.builder(
                        onPageChanged: (value) =>
                            setState(() => _currentIndex = value),
                        itemCount: mediaList.length,
                        itemBuilder: (context, i) {
                          return Image.network(
                            mediaList[i],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image,
                                    color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    // Dots
                    if (mediaList.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(mediaList.length, (index) {
                            return Container(
                              width: 6,
                              height: 6,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: _currentIndex == index
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                );
              },
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
                    widget.item['name'] ?? 'غير متوفر',
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
                    '${widget.item['price']} ريال',
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
                        widget.item['views']?.toString() ?? "0",
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
