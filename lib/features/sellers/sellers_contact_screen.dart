import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../chat/chat_screen.dart';

class SellersContactScreen extends StatefulWidget {
  final String userId;

  const SellersContactScreen({super.key, required this.userId});

  @override
  State<SellersContactScreen> createState() => _SellersContactScreenState();
}

class _SellersContactScreenState extends State<SellersContactScreen> {
  List<SellerContactModel> _sellers = [];
  bool _isLoading = true;
  bool _hasError = false;

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
        setState(() {
          _sellers = data
              .map((item) => SellerContactModel.fromJson(item))
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

  void _showContactOptions(SellerContactModel seller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                // Color(0xFF1A1A2E),
                // Color(0xFF16213E),
                // Color(0xFF0F3460)
                Color(0xFFD4D4F0),
                Color(0xFFC8D4F5),
                Color(0xFFB4D4F0),
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

              // Seller Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      backgroundImage: seller.avatar.isNotEmpty
                          ? NetworkImage(seller.avatar)
                          : null,
                      child: seller.avatar.isEmpty
                          ? Text(
                              seller.name.isNotEmpty ? seller.name[0] : 'S',
                              style: const TextStyle(
                                color: Colors.white,

                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seller.name,
                            style: const TextStyle(
                              // color: Colors.white,
                              color: Color(0xFF1A1A2E),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'البائع',
                            style: TextStyle(
                              // color: Colors.white.withOpacity(0.7),
                              color: const Color(0xFF1A1A2E).withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Contact Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildContactOption(
                      icon: Iconsax.message,
                      title: 'دردشة مباشرة',
                      subtitle: 'تواصل مع البائع عبر الدردشة',
                      onTap: () {
                        Navigator.pop(context);
                        // Create new conversation (no conversationId = new conversation)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              sellerId: seller.id,
                              sellerName: seller.name,
                              sellerAvatar: seller.avatar,
                              sellerToken: seller.token,
                              conversationId:
                                  null, // New conversation for each order
                              isOnline:
                                  false, // TODO: Implement real-time online status
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
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Make phone call
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ميزة المكالمات ستكون متاحة قريباً'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildContactOption(
                      icon: Iconsax.user,
                      title: 'عرض الملف الشخصي',
                      subtitle: 'اطلع على منتجات البائع الأخرى',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to seller profile
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('سيتم فتح ملف البائع الشخصي'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // color: Colors.white.withOpacity(0.1),
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            // color: Colors.white.withOpacity(0.2),
            color: AppColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                // color: Colors.white,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      // color: Colors.white,
                      color: Color(0xFF1A1A2E),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      // color: Colors.white.withOpacity(0.7),
                      color: const Color(0xFF1A1A2E).withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_square_left,
              // color: Colors.white.withOpacity(0.5),
              color: const Color(0xFF1A1A2E).withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // backgroundColor: const Color(0xFF0A0E27),
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            // icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
            icon: const Icon(Iconsax.arrow_right, color: Color(0xFF1A1A2E)),
          ),
          title: const Text(
            'تواصل مع البائعين',
            style: TextStyle(
              // color: Colors.white,
              color: Color(0xFF1A1A2E),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _hasError
            ? _buildErrorWidget()
            : _sellers.isEmpty
            ? _buildEmptyWidget()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sellers.length,
                itemBuilder: (context, index) {
                  return _buildSellerCard(_sellers[index]);
                },
              ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.warning_2, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'حدث خطأ في تحميل البائعين',
            style: TextStyle(
              // color: Colors.white,
              color: Color(0xFF1A1A2E),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSellers,
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

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Iconsax.user_octagon,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد مشتريات سابقة',
            style: TextStyle(
              // color: Colors.white,
              color: Color(0xFF1A1A2E),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'لم تقم بشراء أي منتجات بعد',
            style: TextStyle(
              // color: Colors.white.withOpacity(0.7),
              color: const Color(0xFF1A1A2E).withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'تصفح المنتجات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(SellerContactModel seller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // const Color(0xFF1A1A2E).withOpacity(0.8),
            // const Color(0xFF16213E).withOpacity(0.6),
            Color(0xFFD4D4F0),
            Color(0xFFC8D4F5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.primary,
          backgroundImage: seller.avatar.isNotEmpty
              ? NetworkImage(seller.avatar)
              : null,
          child: seller.avatar.isEmpty
              ? Text(
                  seller.name.isNotEmpty ? seller.name[0] : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          seller.name,
          style: const TextStyle(
            // color: Colors.white,
            color: Color(0xFF1A1A2E),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(
                Iconsax.shop,
                // color: Colors.white.withOpacity(0.6),
                color: const Color(0xFF1A1A2E).withOpacity(0.6),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'البائع',
                style: TextStyle(
                  // color: Colors.white.withOpacity(0.6),
                  color: const Color(0xFF1A1A2E).withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Iconsax.message,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        onTap: () => _showContactOptions(seller),
      ),
    );
  }
}

class SellerContactModel {
  final String id;
  final String name;
  final String avatar;
  final String token;

  SellerContactModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.token,
  });

  factory SellerContactModel.fromJson(Map<String, dynamic> json) {
    return SellerContactModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'avatar': avatar, 'token': token};
  }
}
