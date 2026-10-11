import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/moderation_service.dart';
import '../../core/widgets/moderation_actions.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/smart_avatar_widget.dart';
import '../chat/chat_screen.dart';

class SellersContactScreen extends StatefulWidget {
  final String userId;

  const SellersContactScreen({super.key, required this.userId});

  @override
  State<SellersContactScreen> createState() => _SellersContactScreenState();
}

class _SellersContactScreenState extends State<SellersContactScreen> {
  static const Color _title = Color(0xFF1A1333);
  static const Color _brand = Color(0xFF5C33EA);
  static const Color _sellerTag = Color(0xFF8B7AF0);
  static const Color _border = Color(0xFFEDEAF7);
  static const Color _avatarBorder = Color(0xFFE0DBF5);
  static const Color _iconBadge = Color(0xFFEAE5FC);

  List<SellerContactModel> _sellers = [];
  bool _isLoading = true;
  bool _hasError = false;

  bool get _isAr => LocalizationService.instance.currentLanguage == 'ar';

  @override
  void initState() {
    super.initState();
    _loadSellers();
  }

  Future<void> _loadSellers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ApiService.getUserSellers(userId: widget.userId);

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        await BlockedSellers.instance.sync();
        setState(() {
          _sellers = data
              .map((item) => SellerContactModel.fromJson(item))
              .where(
                (seller) => !BlockedSellers.instance.containsSeller(
                  seller.id,
                  seller.id,
                  seller.name,
                ),
              )
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading sellers: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Widget _buildSellerAvatar(SellerContactModel seller, {double size = 56}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _avatarBorder, width: 1.5),
      ),
      child: ClipOval(
        child: SmartAvatarWidget(
          userId: seller.id,
          name: seller.name,
          size: size - 3,
          fallbackUrl: seller.avatar,
          backgroundColor: _brand,
          initialsStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.32,
          ),
        ),
      ),
    );
  }

  void _showContactOptions(SellerContactModel seller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Directionality(
        textDirection: _isAr ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white24
                      : const Color(0xFFE0DBF5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildSellerAvatar(seller),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seller.name,
                            style: TextStyle(
                              color: isDark ? Colors.white : _title,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(Iconsax.shop, color: _sellerTag, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'البائع',
                                style: TextStyle(
                                  color: _sellerTag,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildContactOption(
                      icon: Iconsax.message,
                      title: 'دردشة مباشرة',
                      subtitle: 'تواصل مع البائع عبر الدردشة',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: seller.id,
                              receiverName: seller.name,
                              receiverAvatar: seller.avatar,
                              receiverToken: seller.token,
                              conversationId: seller.convId,
                              isOnline: false,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildContactOption(
                      icon: Iconsax.call,
                      title: 'مكالمة هاتفية',
                      subtitle: 'اتصل بالبائع مباشرة',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        showAppSnackbar(
                          context,
                          message: 'ميزة المكالمات ستكون متاحة قريباً',
                          type: SnackType.info,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildContactOption(
                      icon: Iconsax.user,
                      title: 'عرض الملف الشخصي',
                      subtitle: 'اطلع على منتجات البائع الأخرى',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        showAppSnackbar(
                          context,
                          message: 'سيتم فتح ملف البائع الشخصي',
                          type: SnackType.info,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildContactOption(
                      icon: Iconsax.flag,
                      title: tr('moderation.report_user'),
                      subtitle: tr('moderation.section_reporting_body'),
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        reportContent(
                          context,
                          targetType: 'user',
                          targetUid: seller.id,
                          title: tr('moderation.report_user'),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildContactOption(
                      icon: Iconsax.user_remove,
                      title: tr('moderation.block'),
                      subtitle: tr('moderation.block_confirm_body'),
                      isDark: isDark,
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final blocked = await blockAbusiveUser(
                          context,
                          blockedUid: seller.id,
                          name: seller.name,
                        );
                        if (blocked && mounted) {
                          setState(() {
                            _sellers.removeWhere((row) => row.id == seller.id);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20 + MediaQuery.of(sheetContext).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkElevated : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : _border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? _brand.withValues(alpha: 0.2)
                      : _iconBadge,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: _brand, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : _title,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF6B6B80),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : const Color(0xFF8B7AF0),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final titleColor = isDark ? Colors.white : _title;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: titleColor,
            ),
          ),
          title: Text(
            isAr ? 'تواصل مع البائعين' : 'Contact sellers',
            style: TextStyle(
              color: titleColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _brand))
            : _hasError
                ? _buildErrorWidget(isDark: isDark)
                : _sellers.isEmpty
                    ? _buildEmptyWidget(isDark: isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _sellers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildSellerCard(
                            _sellers[index],
                            isDark: isDark,
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildErrorWidget({required bool isDark}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.warning_2, size: 72, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            _isAr ? 'حدث خطأ في تحميل البائعين' : 'Failed to load sellers',
            style: TextStyle(
              color: isDark ? Colors.white : _title,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSellers,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            child: Text(_isAr ? 'إعادة المحاولة' : 'Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget({required bool isDark}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: isDark
                    ? _brand.withValues(alpha: 0.15)
                    : _iconBadge,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.user_octagon,
                size: 52,
                color: _brand,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isAr ? 'لا توجد مشتريات سابقة' : 'No previous purchases',
              style: TextStyle(
                color: isDark ? Colors.white : _title,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isAr
                  ? 'لم تقم بشراء أي منتجات بعد'
                  : 'You have not purchased any products yet',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : const Color(0xFF6B6B80),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isAr ? 'تصفح المنتجات' : 'Browse products',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerCard(
    SellerContactModel seller, {
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showContactOptions(seller),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : _border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _brand.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Chat badge — start side of the row content.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? _brand.withValues(alpha: 0.2)
                      : _iconBadge,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Iconsax.message,
                  color: _brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : _title,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Iconsax.shop, color: _sellerTag, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _isAr ? 'البائع' : 'Seller',
                          style: const TextStyle(
                            color: _sellerTag,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildSellerAvatar(seller, size: 56),
            ],
          ),
        ),
      ),
    );
  }
}

class SellerContactModel {
  final String id;
  final String name;
  final String avatar;
  final String token;
  final String convId;

  SellerContactModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.token,
    required this.convId,
  });

  factory SellerContactModel.fromJson(Map<String, dynamic> json) {
    return SellerContactModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      convId: json['convId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'token': token,
      'convId': convId,
    };
  }
}
