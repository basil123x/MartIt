import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/services/auth_service.dart';
import '../shipping/shipping_address_screen.dart';

class OrderSummaryScreen extends StatefulWidget {
  final String userId;
  final List<CartItemModel> cartItems;
  final double totalAmount;

  const OrderSummaryScreen({
    super.key,
    required this.userId,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // backgroundColor: const Color(0xFF0A0E27),
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            // icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
            icon: const Icon(Iconsax.arrow_right, color: Color(0xFF1A1A2E)),
          ),
          title: const Text(
            'ملخص الطلب',
            style: TextStyle(
              // color: Colors.white,
              color: Color(0xFF1A1A2E),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Items Section
                    _buildSectionTitle('عناصر الطلب'),
                    const SizedBox(height: 16),
                    ...widget.cartItems.map((item) => _buildOrderItem(item)),

                    const SizedBox(height: 24),

                    // Order Summary Section
                    _buildSectionTitle('ملخص التكلفة'),
                    const SizedBox(height: 16),
                    _buildOrderSummary(),
                  ],
                ),
              ),
            ),

            // Continue Button
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary.withOpacity(0.2), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            title == 'عناصر الطلب' ? Iconsax.shopping_bag : Iconsax.receipt,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              // color: Colors.white,
              color: Color(0xFF1A1A2E),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CartItemModel cartItem) {
    final itemTotal = double.parse(cartItem.item.price) * cartItem.cartQuantity;
    String thumbnail = "https://martit.s3.ap-south-1.amazonaws.com/store_2/${cartItem.item.idx}/1.png";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // const Color(0xFF1A1A2E).withOpacity(0.6),
            // const Color(0xFF16213E).withOpacity(0.4),
            Color(0xFFD4D4F0),
            Color(0xFFC8D4F5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: cartItem.item.idx.isNotEmpty
                  ? Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Iconsax.image,
                            color: Colors.grey,
                            size: 30,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Iconsax.image,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.item.name,
                  style: const TextStyle(
                    // color: Colors.white,
                    color: Color(0xFF1A1A2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'البائع: ${cartItem.seller.name}',
                  style: TextStyle(
                    // color: Colors.white.withOpacity(0.6),
                    color: const Color(0xFF1A1A2E).withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الكمية: ${cartItem.cartQuantity}',
                        style: const TextStyle(
                          // color: Colors.white,
                          color: Color(0xFF1A1A2E),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${itemTotal.toStringAsFixed(2)} ريال',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = widget.totalAmount;
    const shipping = 0.0; // Free shipping for now
    const tax = 0.0; // No tax for now
    final total = subtotal + shipping + tax;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // const Color(0xFF1A1A2E).withOpacity(0.8),
            // const Color(0xFF0F3460).withOpacity(0.6),
            Color(0xFFD4D4F0),
            Color(0xFFC8D4F5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            'المجموع الفرعي:',
            '${subtotal.toStringAsFixed(2)} ريال',
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'الشحن:',
            shipping == 0 ? 'مجاني' : '${shipping.toStringAsFixed(2)} ريال',
          ),

          // const SizedBox(height: 12),
          // _buildSummaryRow(
          //   'الضريبة:',
          //   tax == 0 ? 'غير مطبقة' : '${tax.toStringAsFixed(2)} ريال',
          // ),
          const SizedBox(height: 16),

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

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المجموع الكلي:',
                style: TextStyle(
                  // color: Colors.white,
                  color: Color(0xFF1A1A2E),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${total.toStringAsFixed(2)} ريال',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            // color: Colors.white.withOpacity(0.8),
            color: const Color(0xFF1A1A2E).withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            // color: Colors.white,
            color: Color(0xFF1A1A2E),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // const Color(0xFF1A1A2E).withOpacity(0.9),
            // const Color(0xFF0F3460),
            Color(0xFFD4D4F0),
            Color(0xFFC8D4F5),
            Color(0xFFB4D4F0),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final currentUid = await AuthService.getCurrentUID();
              if (currentUid != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShippingAddressScreen(
                      userId: widget.userId,
                      uid: currentUid,
                      cartItems: widget.cartItems,
                      totalAmount: widget.totalAmount,
                    ),
                  ),
                );
              }
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'المتابعة إلى الشحن',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Transform.flip(
                  flipX: true,
                  child: const Icon(Iconsax.truck, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
