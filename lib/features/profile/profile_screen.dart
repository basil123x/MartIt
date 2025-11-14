import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/models/item_model.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfileModel? _profile;
  UserProfileItemsModel? _profileItems;
  List _profileLength = [];
  List _filteredItems = []; // القائمة المفلترة للعرض
  bool _isLoading = true;
  bool _isLoading1 = true;
  bool _hasError = false;
  bool _hasError1 = false;
  String _selectedFilter = 'الأحدث';
  final List<String> _filters = ['الأحدث', 'الأكثر مشاهدة', 'الأكثر إعجاباً'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadProfileItems();
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

  Future<void> _loadProfileItems() async {
    setState(() {
      _isLoading1 = true;
      _hasError1 = false;
    });

    try {
      final response = await ApiService.getUserProfileItems(
        int.parse(widget.userId),
      );
      setState(() {
        _profileLength = response['data'];
      });

      if (response['success'] == true) {
        setState(() {
          _profileItems = UserProfileItemsModel.fromJson(response['data']);
          _profileLength = List.from(response['data']); // نسخة من البيانات
          _filteredItems = List.from(
            response['data'],
          ); // عرض كل الأصناف أول مرة
          _isLoading1 = false;
        });
        // تطبيق الفلتر الافتراضي بعد setState
        _applyFilter();
      } else {
        setState(() {
          _hasError1 = true;
          _isLoading1 = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError1 = true;
        _isLoading1 = false;
      });
    }
  }

  // دالة فلترة وترتيب البيانات
  void _applyFilter() {
    List tempList = List.from(_profileLength);

    switch (_selectedFilter) {
      case 'الأحدث':
        // ترتيب حسب created_at أو id (الأحدث أولاً)
        tempList.sort((a, b) {
          // لو فيه created_at استخدمه، لو لأ استخدم id
          if (a['created_at'] != null && b['created_at'] != null) {
            try {
              return DateTime.parse(
                b['created_at'].toString(),
              ).compareTo(DateTime.parse(a['created_at'].toString()));
            } catch (e) {
              // لو فيه مشكلة في parsing التاريخ
              return 0;
            }
          } else if (a['id'] != null && b['id'] != null) {
            int idA = int.tryParse(a['id'].toString()) ?? 0;
            int idB = int.tryParse(b['id'].toString()) ?? 0;
            return idB.compareTo(idA);
          }
          return 0;
        });
        break;

      case 'الأكثر مشاهدة':
        // ترتيب حسب views (الأكثر أولاً)
        tempList.sort((a, b) {
          int viewsA = int.tryParse(a['views']?.toString() ?? '0') ?? 0;
          int viewsB = int.tryParse(b['views']?.toString() ?? '0') ?? 0;
          return viewsB.compareTo(viewsA);
        });
        break;

      case 'الأكثر إعجاباً':
        // ترتيب حسب likes (الأكثر أولاً)
        tempList.sort((a, b) {
          int likesA =
              int.tryParse(
                a['likes']?.toString() ?? a['likes_count']?.toString() ?? '0',
              ) ??
              0;
          int likesB =
              int.tryParse(
                b['likes']?.toString() ?? b['likes_count']?.toString() ?? '0',
              ) ??
              0;
          return likesB.compareTo(likesA);
        });
        break;
    }

    setState(() {
      _filteredItems = tempList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading && _isLoading1
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _hasError && _hasError1
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
            onPressed: _loadProfile,
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
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 300,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.primary,
          leading: Container(),
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              child: _buildProfileHeader(),
            ),
          ),
        ),

        // Filter Buttons
        SliverToBoxAdapter(child: _buildFilterButtons()),

        // Profile Items Grid
        SliverToBoxAdapter(child: _buildItemsGrid()),
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
              border: Border.all(color: Colors.white, width: 4),
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
              backgroundImage: _profile!.avatar.isNotEmpty
                  ? NetworkImage(_profile!.avatar)
                  : null,
              backgroundColor: Colors.white,
              child: _profile!.avatar.isEmpty
                  ? Text(
                      _profile!.name.isNotEmpty ? _profile!.name[0] : 'U',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          // User Name
          Text(
            _profile!.name,
            style: const TextStyle(
              color: Colors.white,
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
              color: Colors.white.withOpacity(0.2),
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
                onPressed: () {
                  setState(() {
                    _selectedFilter = filter;
                    _applyFilter(); // تطبيق الفلتر عند الضغط
                  });
                },
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

  Widget _buildItemsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // عرض النتائج المفلترة
          if (_filteredItems.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'لا توجد منتجات',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
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
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                return _buildItemCard(index);
              },
            ),

          const SizedBox(height: 20),

          // Load More Button
          if (_profile!.itemsCount > 6)
            ElevatedButton(
              onPressed: () {
                // TODO: Load more items
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تحميل المزيد قيد التطوير')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text('تحميل المزيد'),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    return ProfileItemCard(item: _filteredItems[index]);
  }
}

class ProfileItemCard extends StatefulWidget {
  final Map<String, dynamic> item;

  const ProfileItemCard({super.key, required this.item});

  @override
  State<ProfileItemCard> createState() => _ProfileItemCardState();
}

class _ProfileItemCardState extends State<ProfileItemCard> {
  int _currentIndex = 0; // كل card ليها index خاص بيها

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: PageView.builder(
                    onPageChanged: (value) {
                      setState(() {
                        _currentIndex = value;
                      });
                    },
                    itemCount: widget.item['media'].length,
                    itemBuilder: (context, i) {
                      return Image.network(
                        widget.item['media'][i],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
                // Dots Indicator
                if (widget.item['media'].length > 1)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.item['media'].length, (
                        index,
                      ) {
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
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
