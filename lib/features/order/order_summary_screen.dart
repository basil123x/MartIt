import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/widgets/item_thumbnail_widget.dart';
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
  static const Color _title = Color(0xFF1A1333);
  static const Color _muted = Color(0xFF6B6B80);
  static const Color _seller = Color(0xFF8B7AF0);
  static const Color _surfaceSoft = Color(0xFFF5F3FF);
  static const Color _iconBadge = Color(0xFFEAE5FC);
  static const Color _border = Color(0xFFEDEAF7);
  static const Color _brand = Color(0xFF5C33EA);
  static const Color _freeShipping = Color(0xFF2E9E5B);

  bool get _isAr => LocalizationService.instance.currentLanguage == 'ar';

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
            // Auto-mirrors with Directionality (RTL → points right).
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: titleColor,
            ),
          ),
          title: Text(
            isAr ? 'ملخص الطلب' : 'Order Summary',
            style: TextStyle(
              color: titleColor,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: isAr ? 'عناصر الطلب' : 'Order items',
                      icon: Iconsax.shopping_bag,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    ...widget.cartItems.map(
                      (item) => _buildOrderItem(item, isDark: isDark),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      title: isAr ? 'ملخص التكلفة' : 'Cost summary',
                      icon: Iconsax.receipt_2,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildOrderSummary(isDark: isDark),
                  ],
                ),
              ),
            ),
            _buildBottomButton(isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : _surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? _brand.withValues(alpha: 0.2)
                  : _iconBadge,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: _brand, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : _title,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CartItemModel cartItem, {required bool isDark}) {
    final itemTotal =
        (double.tryParse(cartItem.item.price) ?? 0) * cartItem.cartQuantity;
    final currency = _isAr ? 'ريال' : 'QAR';
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : _border;
    final nameColor = isDark ? Colors.white : _title;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ItemThumbnailWidget(
              storeId: cartItem.item.store_id,
              itemId: cartItem.item.id,
              itemIdx: cartItem.item.idx,
              preferredUrl: cartItem.item.thumbnail,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              iconSize: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.item.name,
                  style: TextStyle(
                    color: nameColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Iconsax.shop, size: 14, color: _seller),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cartItem.seller.name,
                        style: const TextStyle(
                          color: _seller,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, thickness: 1, color: borderColor),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkElevated
                            : _surfaceSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isAr
                            ? 'الكمية: ${cartItem.cartQuantity}'
                            : 'Qty: ${cartItem.cartQuantity}',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${itemTotal.toStringAsFixed(2)} $currency',
                      style: const TextStyle(
                        color: _brand,
                        fontSize: 16,
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

  Widget _buildOrderSummary({required bool isDark}) {
    final subtotal = widget.totalAmount;
    const shipping = 0.0;
    final total = subtotal + shipping;
    final currency = _isAr ? 'ريال' : 'QAR';
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : _border;
    final labelColor = isDark ? AppColors.darkTextSecondary : _muted;
    final valueColor = isDark ? Colors.white : _title;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            label: _isAr ? 'المجموع الفرعي' : 'Subtotal',
            value: '${subtotal.toStringAsFixed(2)} $currency',
            labelColor: labelColor,
            valueColor: valueColor,
          ),
          const SizedBox(height: 14),
          _buildSummaryRow(
            label: _isAr ? 'الشحن' : 'Shipping',
            value: shipping == 0
                ? (_isAr ? 'مجاني' : 'Free')
                : '${shipping.toStringAsFixed(2)} $currency',
            labelColor: labelColor,
            valueColor: shipping == 0 ? _freeShipping : valueColor,
            valueBold: shipping == 0,
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: borderColor),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                _isAr ? 'المجموع الكلي' : 'Total',
                style: TextStyle(
                  color: isDark ? Colors.white : _title,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? _brand.withValues(alpha: 0.2)
                      : _iconBadge,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${total.toStringAsFixed(2)} $currency',
                  style: const TextStyle(
                    color: _brand,
                    fontSize: 17,
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

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required Color labelColor,
    required Color valueColor,
    bool valueBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: valueBold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : _border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final currentUid = await AuthService.getCurrentUID();
              if (currentUid == null || !mounted) return;
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shadowColor: _brand.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ).copyWith(
              elevation: const WidgetStatePropertyAll(4),
              shadowColor: WidgetStatePropertyAll(
                _brand.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isAr ? 'المتابعة إلى الشحن' : 'Continue to shipping',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Iconsax.truck, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
