import 'dart:async';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/background_media_upload_service.dart';
import '../../core/services/s3_upload_service.dart';
import '../../core/services/moderation_service.dart';
import '../../core/widgets/report_sheet.dart';
import '../../core/models/item_model.dart';
import '../../core/widgets/media_viewer_widget.dart';
import '../../core/widgets/uploading_media_frame.dart';
import '../../core/widgets/smart_avatar_widget.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/theme_extensions.dart';
import '../add_product/add_product_screen.dart';
import '../orders/customer_orders_screen.dart';
import '../orders/my_orders_screen.dart';
import '../settings/settings_screen.dart';
import '../product/product_detail_screen.dart';
import 'profile_avatar_preview_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  /// When true, hosted inside [MainNavigationScreen] — hide the back control.
  final bool embeddedInShell;

  /// Called after this session's user no longer exists, so the shell can
  /// drop the cached id and open login.
  final VoidCallback? onAccountMissing;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.embeddedInShell = false,
    this.onAccountMissing,
  });

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
  bool _isOwnProfile = false;
  int _avatarCacheTimestamp = DateTime.now().millisecondsSinceEpoch;

  final BackgroundMediaUploadService _uploads =
      BackgroundMediaUploadService.instance;

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
    _resolveOwnership();
    _loadProfile();
    _loadFreshUserDetails();
    _scrollController.addListener(_onScroll);
    _uploads.addListener(_mergePendingUploads);
  }

  @override
  void dispose() {
    _uploads.removeListener(_mergePendingUploads);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveOwnership() async {
    final uid = await AuthService.getCurrentUID();
    if (!mounted) return;
    setState(() {
      _isOwnProfile = uid != null &&
          uid.isNotEmpty &&
          (uid == widget.userId || uid == _itemsOwnerUid);
    });
    _mergePendingUploads();
  }

  void _mergePendingUploads() {
    if (!mounted || !_isOwnProfile) return;
    final missing = <Map<String, dynamic>>[];
    for (final itemId in _uploads.activeItemIds()) {
      final exists = _items.any((item) => item['id']?.toString() == itemId);
      if (exists) continue;
      final snapshot = _uploads.profileSnapshot(itemId);
      if (snapshot == null) continue;
      missing.add(snapshot);
    }
    if (missing.isEmpty) return;
    setState(() {
      _items.insertAll(0, missing);
      _isLoadingItems = false;
    });
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final itemId = item['id']?.toString() ?? '';
    if (itemId.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await DatabaseService.getItem(itemId);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    Map<String, dynamic> data;
    if (response['success'] == true && response['data'] != null) {
      data = Map<String, dynamic>.from(response['data'] as Map);
    } else {
      // Fallback to the list payload if get_item isn't deployed yet
      data = Map<String, dynamic>.from(item);
    }

    final media = data['media'];
    final mediaFiles = media is List
        ? media.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          mediaFiles: mediaFiles,
          itemId: itemId,
          isEditing: true,
          existingItem: data,
        ),
      ),
    );

    if (result != null) {
      _loadItems();
      _loadProfile();
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item, int index) async {
    final itemId = item['id']?.toString() ?? '';
    if (itemId.isEmpty) return;

    final lang = LocalizationService.instance.currentLanguage;
    final isAr = lang == 'ar';

    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: isAr ? 'حذف المنتج' : 'Delete Product',
      desc: isAr
          ? 'هل أنت متأكد من حذف هذا المنتج نهائيًا؟'
          : 'Are you sure you want to permanently delete this product?',
      btnCancelText: isAr ? 'إلغاء' : 'Cancel',
      btnOkText: isAr ? 'حذف' : 'Delete',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final removed = _items[index];
        setState(() {
          _items.removeAt(index);
          if (_profile != null && _profile!.itemsCount > 0) {
            _profile = UserProfileModel(
              id: _profile!.id,
              uid: _profile!.uid,
              name: _profile!.name,
              phone: _profile!.phone,
              avatar: _profile!.avatar,
              type: _profile!.type,
              itemsCount: _profile!.itemsCount - 1,
            );
          }
        });

        final result = await DatabaseService.deleteItem(itemId);
        if (!mounted) return;

        if (result['success'] == true) {
          final media = removed['media'];
          if (media is List) {
            for (final url in media) {
              final u = url.toString();
              if (u.startsWith('http')) {
                // Best-effort S3 cleanup; ignore failures
                unawaited(S3UploadService.deleteFile(u));
              }
            }
          }
          showAppSnackbar(
            context,
            message: isAr ? 'تم حذف المنتج' : 'Product deleted',
            type: SnackType.success,
          );
        } else {
          setState(() {
            _items.insert(index.clamp(0, _items.length), removed);
            if (_profile != null) {
              _profile = UserProfileModel(
                id: _profile!.id,
                uid: _profile!.uid,
                name: _profile!.name,
                phone: _profile!.phone,
                avatar: _profile!.avatar,
                type: _profile!.type,
                itemsCount: _profile!.itemsCount + 1,
              );
            }
          });
          showAppSnackbar(
            context,
            message: isAr
                ? 'تعذر حذف المنتج، حاول مرة أخرى'
                : 'Could not delete the product, please try again',
            type: SnackType.error,
          );
        }
      },
    ).show();
  }

  String get _itemsOwnerUid =>
      (_profile?.uid.isNotEmpty == true) ? _profile!.uid : widget.userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(_bumpAvatarCache);
    _loadFreshUserDetails();
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
        await _resolveOwnership();
        await _loadFreshUserDetails();
        _loadItems();
      } else if (await _signOutIfAccountMissing(response)) {
        return;
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

  bool _isMissingAccountError(dynamic response) {
    if (response is! Map) return false;
    final error = response['error']?.toString() ?? '';
    return error == 'المستخدم غير موجود' ||
        error == 'user not found' ||
        error == 'uid missing';
  }

  /// Clears the local session when this profile is the signed-in user and
  /// the server no longer has that account.
  Future<bool> _signOutIfAccountMissing(dynamic response) async {
    if (!_isMissingAccountError(response)) return false;
    final currentUid = await AuthService.getCurrentUID();
    if (currentUid == null || currentUid != widget.userId) return false;
    await AuthService.logout();
    if (!mounted) return true;
    final notify = widget.onAccountMissing;
    if (notify != null) {
      notify();
      return true;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return true;
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
        _mergePendingUploads();
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

  Future<void> _reportOrBlockProfile() async {
    final uid = await AuthService.getCurrentUserId();
    if (!mounted || uid == null) return;
    final target =
        _profile?.uid.isNotEmpty == true ? _profile!.uid : widget.userId;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(tr('moderation.report')),
              onTap: () {
                Navigator.pop(sheetContext);
                showReportSheet(
                  context: context,
                  title: tr('moderation.report'),
                  onSubmit: (reason, note) async {
                    final result = await ModerationService.report(
                      userId: uid,
                      reason: reason,
                      note: note,
                      targetType: 'user',
                      targetUid: target,
                    );
                    if (!mounted) return;
                    final sent = result['success'] == true;
                    showAppSnackbar(
                      context,
                      message: sent
                          ? tr('moderation.report_sent')
                          : tr('common.error'),
                      type: sent ? SnackType.success : SnackType.error,
                    );
                  },
                );
              },
            ),
            ListTile(
              title: Text(tr('moderation.block')),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await ModerationService.blockUser(
                  blockerUid: uid,
                  blockedUid: target,
                );
                if (!mounted) return;
                if (result['success'] == true) {
                  BlockedSellers.instance.block(
                    [
                      target,
                      widget.userId,
                      _profile?.id ?? '',
                      _profile?.uid ?? '',
                    ],
                    name: _profile?.name ?? '',
                  );
                  showAppSnackbar(context, message: tr('moderation.blocked'));
                  Navigator.pop(context);
                } else {
                  showAppSnackbar(
                    context,
                    message: tr('common.error'),
                    type: SnackType.error,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.appPrimary),
            )
          : _hasError
          ? _buildErrorState()
          : _buildProfileContent(),
    );
  }

  Widget _buildErrorState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.warning_2, size: 64, color: cs.error),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ في تحميل الملف الشخصي',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _loadProfile();
              _loadItems();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    if (_profile == null) return const SizedBox();

    final cs = Theme.of(context).colorScheme;
    final headerBg = cs.surfaceContainerHighest;

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
          backgroundColor: headerBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          forceElevated: false,
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
                      Flexible(
                        child: Text(
                          _profile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
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
                  icon: Icon(Iconsax.setting_2, color: cs.primary),
                );
              }
              return const SizedBox();
            },
          ),
          actions: [
            if (!_isOwnProfile)
              IconButton(
                onPressed: _reportOrBlockProfile,
                icon: Icon(Iconsax.user_remove, color: cs.primary),
              ),
            if (!widget.embeddedInShell)
              IconButton(
                onPressed: () => Navigator.pop(context),
                // Back lives in `actions` (left in RTL / right in LTR).
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: cs.primary,
                  size: 18,
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: ColoredBox(
              color: headerBg,
              child: _buildProfileHeader(),
            ),
          ),
        ),

        // Own-account order shortcuts
        SliverToBoxAdapter(child: _buildOrdersShortcuts()),

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
        final cs = Theme.of(context).colorScheme;

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
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.primary, width: 2),
                  ),
                  child: SmartAvatarWidget(
                    userId: userId,
                    name: _profile!.name,
                    size: 106,
                    cacheTimestamp: _avatarCacheTimestamp,
                    loadSocialFromStorage: isOwnProfile,
                    fallbackUrl: _profile!.avatar.isNotEmpty ? _profile!.avatar : null,
                    heroTag: _avatarHeroTag,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _profile!.name,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: context.appIconPillBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_profile!.itemsCount} منتج',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersShortcuts() {
    if (!_isOwnProfile) return const SizedBox.shrink();

    final isAr = LocalizationService.instance.currentLanguage == 'ar';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _buildOrderShortcut(
              icon: Iconsax.bag,
              title: isAr ? 'طلباتي' : 'My Orders',
              subtitle: isAr ? 'الطلبات التي قدّمتها' : 'Orders you placed',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyOrdersScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildOrderShortcut(
              icon: Iconsax.bag_tick,
              title: isAr ? 'طلبات العملاء' : 'Customer Orders',
              subtitle: isAr ? 'مشتريات زبائنك' : 'Orders from your buyers',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerOrdersScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderShortcut({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDarkMode;
    return Material(
      color: isDark
          ? AppColors.primary.withValues(alpha: 0.18)
          : AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.fieldBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: isSelected
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => _onFilterChanged(filter),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      filter,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? cs.onPrimary
                            : cs.onSurfaceVariant,
                      ),
                    ),
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
      padding: EdgeInsets.fromLTRB(
        8,
        0,
        8,
        widget.embeddedInShell ? 100 : 16,
      ),
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
                final item = _items[index];
                return ProfileItemCard(
                  item: item,
                  showOwnerActions: _isOwnProfile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(item: item),
                    ),
                  ),
                  onEdit: () => _editItem(item),
                  onDelete: () => _deleteItem(item, index),
                );
              },
            ),

          // Loading More Indicator
          if (_isLoadingMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: context.appPrimary),
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
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.shop_add,
                size: 90,
                color: martIt.emptyIcon,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد منتجات بعد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بإضافة منتجاتك الآن',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsErrorState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.warning_2,
              size: 48,
              color: cs.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'فشل في تحميل المنتجات',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
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
  final bool showOwnerActions;
  final VoidCallback? onTap;

  static List<String> _itemMediaUrls(Map<String, dynamic> item) {
    final media = item['media'];
    if (media is List) {
      return media.map((e) => e.toString()).where((e) => e.startsWith('http')).toList();
    }
    final raw = media?.toString() ?? '';
    if (raw.startsWith('http')) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ProfileItemCard({
    super.key,
    required this.item,
    this.showOwnerActions = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = item['price']?.toString().trim() ?? '';
    final priceLabel = price.isEmpty ? '—' : price;

    return Card(
      color: context.isDarkMode
          ? AppColors.darkSurface
          : const Color(0xFFB4D4F0).withAlpha(40),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.primary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: UploadingMediaFrame(
                      itemId: "${item["id"] ?? ""}",
                      ready: MediaViewerWidget(
                        mediaUrls: _itemMediaUrls(item),
                        itmId: "${item["id"] ?? ""}",
                        itmIdx: "${item["idx"] ?? ""}",
                        storeid:
                            "${item["storeid"] ?? item["store_id"] ?? "1"}",
                        autoPlayVideo: false,
                        showControls: false,
                        showIndicators: false,
                      ),
                    ),
                  ),
                  if (showOwnerActions)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Row(
                        children: [
                          _OwnerActionButton(
                            icon: Iconsax.edit_2,
                            background: const Color(0xFF5C33EA),
                            onTap: onEdit,
                          ),
                          const SizedBox(width: 6),
                          _OwnerActionButton(
                            icon: Iconsax.trash,
                            background: Colors.red,
                            onTap: onDelete,
                          ),
                        ],
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
                      item['name']?.toString().isNotEmpty == true
                          ? item['name'].toString()
                          : 'غير متوفر',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$priceLabel ريال',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Iconsax.eye, size: 12, color: cs.onSurfaceVariant),
                        Text(
                          item['views']?.toString() ?? "0",
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
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
      ),
    );
  }
}

class _OwnerActionButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final VoidCallback? onTap;

  const _OwnerActionButton({
    required this.icon,
    required this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, color: Colors.white, size: 15),
        ),
      ),
    );
  }
}
