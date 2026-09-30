import 'dart:math';

import 'package:MartIt/features/home/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/shipping_address_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../orders/invoice_screen.dart';
import '../sellers/sellers_contact_screen.dart';
import '../../core/services/api_config_service.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String userId;
  final List<CartItemModel> cartItems;
  final double totalAmount;
  final ShippingAddressModel shippingAddress;

  const PaymentSuccessScreen({
    super.key,
    required this.userId,
    required this.cartItems,
    required this.totalAmount,
    required this.shippingAddress,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  static const Color _title = Color(0xFF1A1333);
  static const Color _muted = Color(0xFF6B6B80);
  static const Color _brand = Color(0xFF5C33EA);
  static const Color _border = Color(0xFFEDEAF7);
  static const Color _outline = Color(0xFFE0DBF5);
  static const Color _iconBadge = Color(0xFFEAE5FC);
  static const Color _success = Color(0xFF2E9E5B);
  static const Color _successSoft = Color(0xFF34C471);
  static const Color _noticeBg = Color(0xFFEAF7EF);
  static const Color _noticeBorder = Color(0xFFB8E6C8);

  String? _createdOrderOid;

  bool get _isAr => LocalizationService.instance.currentLanguage == 'ar';

  @override
  void initState() {
    super.initState();
    _createOrders();
  }

  Future<void> _createOrders() async {
    try {
      final currentOid = await AuthService.getCurrentOID();

      final Map<String, List<CartItemModel>> itemsBySeller = {};
      for (var item in widget.cartItems) {
        final sellerId = item.seller.id;
        itemsBySeller.putIfAbsent(sellerId, () => []);
        itemsBySeller[sellerId]!.add(item);
      }

      for (final entry in itemsBySeller.entries) {
        final sellerId = entry.key;
        final sellerItems = entry.value;

        double sellerTotal = 0.0;
        for (var item in sellerItems) {
          sellerTotal += double.parse(item.item.price) * item.cartQuantity;
        }

        final itemsJson =
            '[${sellerItems.map((item) => '{"id":"${item.item.id}","name":"${item.item.name}","price":"${item.item.price}","quantity":${item.cartQuantity}}').join(',')}]';

        final result = await ApiService.createOrder(
          uid: sellerId,
          custId: widget.userId,
          oid: currentOid ?? '',
          shipId: widget.shippingAddress.id.toString(),
          items: itemsJson,
          totalAmount: sellerTotal.toStringAsFixed(2),
        );

        print('Order API response: $result');
        print('✅ Order created for seller $sellerId: $result');
      }

      if (mounted) {
        setState(() {
          _createdOrderOid = currentOid;
        });
      }
    } catch (e) {
      print('❌ Error creating orders: $e');
    }
  }

  Future<void> _clearCartAndUpdateOID() async {
    try {
      final newOid = (1000 + Random().nextInt(9000)).toString();

      await ApiService.clearCartAndUpdateOID(
        userId: widget.userId,
        newOid: newOid,
      );

      const storage = FlutterSecureStorage();
      await storage.write(key: 'user_oid', value: newOid);

      print('✅ Cart cleared and OID updated to: $newOid');
    } catch (e) {
      print('❌ Error clearing cart and updating OID: $e');
    }
  }

  void _openInvoice(String orderId) {
    final invoiceNumber = orderId.isNotEmpty ? orderId : '—';
    final shareUrl = orderId.isEmpty
        ? null
        : ApiConfigService.instance.endpoint(
            'invoice.php?order_id=$orderId&view=customer'
            '&k=${DateTime.now().millisecondsSinceEpoch}',
          );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceScreen.fromCheckout(
          invoiceNumber: invoiceNumber,
          cartItems: widget.cartItems,
          shippingAddress: widget.shippingAddress,
          totalAmount: widget.totalAmount,
          shareUrl: shareUrl,
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
    final mutedColor = isDark ? AppColors.darkTextSecondary : _muted;
    final currency = isAr ? 'ريال' : 'QAR';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.7, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) {
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: _successSoft,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _success.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          isAr ? 'تم الدفع بنجاح!' : 'Payment successful!',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isAr
                              ? 'شكراً لك، تم تأكيد طلبك بنجاح'
                              : 'Thank you, your order has been confirmed',
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 15,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildOrderSummaryCard(
                          isDark: isDark,
                          titleColor: titleColor,
                          mutedColor: mutedColor,
                          currency: currency,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
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
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shadowColor: _brand.withValues(alpha: 0.28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ).copyWith(
                      elevation: const WidgetStatePropertyAll(3),
                    ),
                    icon: const Icon(Iconsax.message, size: 20),
                    label: Text(
                      isAr ? 'تواصل مع البائعين' : 'Contact sellers',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final oid = _createdOrderOid ??
                              (widget.cartItems.isNotEmpty
                                  ? widget.cartItems.first.orderId
                                  : '');
                          _openInvoice(oid);
                        },
                        style: _secondaryButtonStyle(),
                        icon: const Icon(Iconsax.bill, size: 18),
                        label: Text(
                          isAr ? 'عرض فاتورتك' : 'View invoice',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _clearCartAndUpdateOID();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MainNavigationScreen(),
                            ),
                          );
                        },
                        style: _secondaryButtonStyle(),
                        icon: const Icon(Iconsax.home, size: 18),
                        label: Text(
                          isAr ? 'الرئيسية' : 'Home',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _brand,
      side: const BorderSide(color: _outline, width: 1.2),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _buildOrderSummaryCard({
    required bool isDark,
    required Color titleColor,
    required Color mutedColor,
    required String currency,
  }) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : _border;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
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
                child: const Icon(Iconsax.receipt_2, color: _brand, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                _isAr ? 'ملخص الطلب' : 'Order summary',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSummaryRow(
            label: _isAr ? 'عدد العناصر' : 'Items',
            value: _isAr
                ? '${widget.cartItems.length} عنصر'
                : '${widget.cartItems.length} items',
            labelColor: mutedColor,
            valueColor: titleColor,
            showDivider: true,
            borderColor: borderColor,
          ),
          _buildSummaryRow(
            label: _isAr ? 'المبلغ الإجمالي' : 'Total amount',
            value: '${widget.totalAmount.toStringAsFixed(2)} $currency',
            labelColor: mutedColor,
            valueColor: _brand,
            valueBold: true,
            showDivider: true,
            borderColor: borderColor,
          ),
          _buildSummaryRow(
            label: _isAr ? 'العنوان' : 'Address',
            value: widget.shippingAddress.formattedAddress,
            labelColor: mutedColor,
            valueColor: titleColor,
            showDivider: false,
            borderColor: borderColor,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? _success.withValues(alpha: 0.12)
                  : _noticeBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? _success.withValues(alpha: 0.35)
                    : _noticeBorder,
              ),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.info_circle, color: _success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isAr
                        ? 'سيتم التواصل معك قريباً لتأكيد التسليم'
                        : 'We will contact you soon to confirm delivery',
                    style: const TextStyle(
                      color: _success,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
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
    required bool showDivider,
    required Color borderColor,
    bool valueBold = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 14,
                    fontWeight:
                        valueBold ? FontWeight.bold : FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: borderColor),
      ],
    );
  }
}
