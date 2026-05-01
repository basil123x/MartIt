import 'dart:math';
import 'package:GlobalFarm/features/home/tiktok_feed_screen.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/shipping_address_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../sellers/sellers_contact_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  final String? transStatus;
  final String userId;
  final List<CartItemModel> cartItems;
  final double totalAmount;
  final ShippingAddressModel shippingAddress;

  const OrderSuccessScreen({
    super.key,
    this.transStatus,
    required this.userId,
    required this.cartItems,
    required this.totalAmount,
    required this.shippingAddress,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    if (widget.transStatus == '3') {
      _createOrders();
    }
  }

  Future<void> _createOrders() async {
    try {
      // Group cart items by seller
      Map<String, List<CartItemModel>> itemsBySeller = {};
      for (var cartItem in widget.cartItems) {
        String sellerId = cartItem.seller.id;
        if (!itemsBySeller.containsKey(sellerId)) {
          itemsBySeller[sellerId] = [];
        }
        itemsBySeller[sellerId]!.add(cartItem);
      }

      // Get current OID
      final currentOid = await AuthService.getCurrentOID();

      // Create order for each seller
      for (var entry in itemsBySeller.entries) {
        String sellerId = entry.key;
        List<CartItemModel> sellerItems = entry.value;

        // Calculate total for this seller
        double sellerTotal = 0.0;
        for (var item in sellerItems) {
          sellerTotal += (double.parse(item.item.price) * item.cartQuantity);
        }

        // Prepare items JSON
        String itemsJson = sellerItems
            .map(
              (item) =>
                  '{"id":"${item.item.id}","name":"${item.item.name}","price":"${item.item.price}","quantity":${item.cartQuantity}}',
            )
            .join(',');
        itemsJson = '[$itemsJson]';

        // Create order
        await ApiService.createOrder(
          uid: sellerId,
          custId: widget.userId,
          oid: currentOid ?? '',
          shipId: widget.shippingAddress.id.toString(),
          items: itemsJson,
          totalAmount: sellerTotal.toStringAsFixed(2),
        );
      }

      print('✅ Orders created successfully');
    } catch (e) {
      print('❌ Error creating orders: $e');
    }
  }

  Future<void> _clearCartAndUpdateOID() async {
    try {
      // Generate new 4-digit OID
      final newOid = (1000 + Random().nextInt(9000)).toString();

      // Clear cart and update OID in database
      await ApiService.clearCartAndUpdateOID(
        userId: widget.userId,
        newOid: newOid,
      );

      // Update OID in local storage
      const storage = FlutterSecureStorage();
      await storage.write(key: 'user_oid', value: newOid);

      print('✅ Cart cleared and OID updated to: $newOid');
    } catch (e) {
      print('❌ Error clearing cart and updating OID: $e');
    }
  }

  Future<void> _openInvoice(String orderId) async {
    print("My Bill Order Id ---> $orderId");
    final Uri url = Uri.parse(
      'https://www.Globee-Trading.com/app2026/invoice.php?order_id=$orderId&store_id=2&k=${DateTime.now().millisecondsSinceEpoch}',
    );

    if (!await launchUrl(
      url,
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    )) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('فشل فتح الفاتورة')));
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(widget.transStatus);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Success Animation with Green Glow
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.green.withOpacity(0.4),
                                    Colors.green.withOpacity(0.2),
                                    Colors.green.withOpacity(0.05),
                                    Colors.transparent,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: widget.transStatus != '3' ? Colors.red : Colors.green,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.transStatus != '3' ? Colors.red :Colors.green.withOpacity(0.35),
                                        blurRadius: 40,
                                        spreadRadius: widget.transStatus != '3' ? 1 : 15,
                                      ),
                                      BoxShadow(
                                        color: widget.transStatus != '3' ? Colors.red : Colors.green.withOpacity(0.15),
                                        blurRadius: 70,
                                        spreadRadius: widget.transStatus != '3' ? 1 : 30,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.transStatus != '3' ? Icons.close_rounded : Icons.check_rounded,
                                    color: Colors.white,
                                    size: 55,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Success Message
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              widget.transStatus != '3' ? 'لقد فشلت العملية!' : 'تم الدفع بنجاح!',
                              style: TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.transStatus != '3' ? 'للاسف, لم تنجح العملية حاول مرة أخرى' : 'شكراً لك، تم تأكيد طلبك بنجاح',
                              style: TextStyle(
                                color: const Color(0xFF1A1A2E).withOpacity(0.7),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Order Summary Card with Purple/Lavender Background
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFD4D4F0),
                                const Color(0xFFC8D4F5),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Header with Receipt Icon
                              Row(
                                children: [
                                  Icon(
                                    Iconsax.receipt_2,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'ملخص الطلب',
                                    style: TextStyle(
                                      color: Color(0xFF1A1A2E),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Number of Items
                              _buildSummaryRow(
                                'عدد العناصر',
                                '${widget.cartItems.length} عنصر',
                              ),
                              const SizedBox(height: 12),
                              
                              // Total Amount
                              _buildSummaryRow(
                                'المبلغ الإجمالي',
                                '${widget.totalAmount.toStringAsFixed(2)} ريال',
                              ),
                              const SizedBox(height: 12),
                              
                              // Address
                              _buildSummaryRow(
                                'العنوان',
                                '${widget.shippingAddress.city}, ${widget.shippingAddress.country}, شارع ${widget.shippingAddress.streetNumber}, مبنى ${widget.shippingAddress.buildingNumber}, منطقة ${widget.shippingAddress.zoneNumber}',
                              ),


                              // Info Box
                                Visibility(
                                  visible: widget.transStatus != '3' ? false : true,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Iconsax.info_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'سيتم التواصل معك قريباً لتأكيد التسليم',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Contact Sellers Button (Primary - Olive Green)
                      Visibility(
                        visible: widget.transStatus != '3' ? false : true,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SellersContactScreen(userId: widget.userId),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 8,
                            ),
                            icon: const Icon(Iconsax.message),
                            label: const Text(
                              'تواصل مع البائعين',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Secondary Row: Home and Invoice Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (widget.transStatus == '3') {
                                  _clearCartAndUpdateOID();
                                }
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TikTokFeedScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1A1A2E),
                                side: BorderSide(
                                  color: const Color(0xFF1A1A2E).withOpacity(0.3),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              icon: const Icon(Iconsax.home),
                              label: const Text(
                                'الرئيسية',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (widget.transStatus == '3')
                          const SizedBox(width: 16),
                          if (widget.transStatus == '3')
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                String orderId = "";
                                for (var carto in widget.cartItems) {
                                  orderId = carto.orderId;
                                }
                                _openInvoice(orderId);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1A1A2E),
                                side: BorderSide(
                                  color: const Color(0xFF1A1A2E).withOpacity(0.3),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              icon: const Icon(Iconsax.bill),
                              label: const Text(
                                'عرض فاتورتك',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF1A1A2E).withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '→',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.start,
          ),
        ),
      ],
    );
  }
}
