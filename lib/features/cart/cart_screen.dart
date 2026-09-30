import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/item_thumbnail_widget.dart';
import '../order/order_summary_screen.dart';

/// Full-screen cart / checkout entry, backed by the same cart API used by
/// the feed inline quantity control.
class CartScreen extends StatefulWidget {
  final String userId;

  /// Called whenever quantities change so the feed can stay in sync.
  /// Map of itemId → quantity (0 means removed).
  final ValueChanged<Map<String, int>>? onCartUpdated;

  const CartScreen({
    super.key,
    required this.userId,
    this.onCartUpdated,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const Color _brand = Color(0xFF5C33EA);
  static const Color _destructive = Color(0xFFE5484D);

  List<CartItemModel> _cartItems = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isClearing = false;

  bool get _isAr => LocalizationService.instance.currentLanguage == 'ar';

  double get _subtotal {
    var total = 0.0;
    for (final item in _cartItems) {
      total += (double.tryParse(item.item.price) ?? 0) * item.cartQuantity;
    }
    return total;
  }

  double get _total => _subtotal;

  Map<String, List<CartItemModel>> get _groupedBySeller {
    final map = <String, List<CartItemModel>>{};
    for (final item in _cartItems) {
      map.putIfAbsent(item.seller.id, () => []).add(item);
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  void _emitCartUpdate({Iterable<String>? clearedItemIds}) {
    final snapshot = <String, int>{
      for (final item in _cartItems) item.item.id: item.cartQuantity,
    };
    if (clearedItemIds != null) {
      for (final id in clearedItemIds) {
        snapshot.putIfAbsent(id, () => 0);
      }
    }
    widget.onCartUpdated?.call(snapshot);
  }

  void _confirmClearCart() {
    if (_cartItems.isEmpty || _isClearing) return;

    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: _isAr ? 'تفريغ السلة؟' : 'Clear cart?',
      desc: _isAr
          ? 'سيتم حذف جميع المنتجات من سلة التسوق'
          : 'All products will be removed from your cart',
      btnCancelText: _isAr ? 'إلغاء' : 'Cancel',
      btnOkText: _isAr ? 'حذف الكل' : 'Delete all',
      btnOkColor: _destructive,
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        _clearCart();
      },
    ).show();
  }

  Future<void> _clearCart() async {
    if (_cartItems.isEmpty || _isClearing) return;

    final previousItems = List<CartItemModel>.from(_cartItems);
    final clearedIds = previousItems.map((i) => i.item.id).toList();

    setState(() {
      _isClearing = true;
      _cartItems = [];
    });
    _emitCartUpdate(clearedItemIds: clearedIds);

    try {
      final results = await Future.wait(
        previousItems.map(
          (item) => ApiService.updateCartQuantity(
            cartId: item.cartId,
            quantity: 0,
          ),
        ),
      );

      if (!mounted) return;

      final anyFailed = results.any((r) => r['success'] != true);
      if (anyFailed) {
        setState(() {
          _cartItems = previousItems;
          _isClearing = false;
        });
        _emitCartUpdate();
        showAppSnackbar(
          context,
          message: _isAr
              ? 'تعذر تفريغ السلة بالكامل'
              : 'Could not clear the entire cart',
          type: SnackType.error,
        );
        await _loadCartItems();
        return;
      }

      setState(() => _isClearing = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cartItems = previousItems;
        _isClearing = false;
      });
      _emitCartUpdate();
      showAppSnackbar(
        context,
        message: _isAr ? 'حدث خطأ أثناء تفريغ السلة' : 'Error clearing cart',
        type: SnackType.error,
      );
      await _loadCartItems();
    }
  }

  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ApiService.getCartItems(userId: widget.userId);
      if (!mounted) return;

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _cartItems = data
              .map(
                (item) => CartItemModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
          _isLoading = false;
        });
        _emitCartUpdate();
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(CartItemModel cartItem, int newQuantity) async {
    final previous = cartItem.cartQuantity;
    setState(() {
      if (newQuantity <= 0) {
        _cartItems.removeWhere((i) => i.cartId == cartItem.cartId);
      } else {
        cartItem.cartQuantity = newQuantity;
      }
    });
    _emitCartUpdate();

    try {
      final result = await ApiService.updateCartQuantity(
        cartId: cartItem.cartId,
        quantity: newQuantity < 0 ? 0 : newQuantity,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        // Revert optimistic update
        setState(() {
          if (newQuantity <= 0) {
            cartItem.cartQuantity = previous;
            _cartItems.add(cartItem);
          } else {
            cartItem.cartQuantity = previous;
          }
        });
        _emitCartUpdate();
        showAppSnackbar(
          context,
          message: result['error']?.toString() ??
              (_isAr ? 'فشل في التحديث' : 'Update failed'),
          type: SnackType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (newQuantity <= 0) {
          cartItem.cartQuantity = previous;
          _cartItems.add(cartItem);
        } else {
          cartItem.cartQuantity = previous;
        }
      });
      _emitCartUpdate();
      showAppSnackbar(
        context,
        message: _isAr ? 'حدث خطأ أثناء التحديث' : 'Error updating cart',
        type: SnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              isAr ? Iconsax.arrow_right_3 : Iconsax.arrow_left_2,
              color: context.appTextPrimary,
            ),
          ),
          title: Text(
            isAr ? 'سلة التسوق' : 'Shopping Cart',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            if (!_isLoading && !_hasError && _cartItems.isNotEmpty)
              IconButton(
                onPressed: _isClearing ? null : _confirmClearCart,
                tooltip: isAr ? 'تفريغ السلة' : 'Clear cart',
                icon: _isClearing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _destructive,
                        ),
                      )
                    : const Icon(Iconsax.trash, color: _destructive),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _brand))
            : _hasError
                ? _buildError()
                : _cartItems.isEmpty
                    ? _buildEmpty()
                    : Column(
                        children: [
                          Expanded(child: _buildGroupedList()),
                          _buildBottomSummary(),
                        ],
                      ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.warning_2, size: 72, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _isAr ? 'حدث خطأ في تحميل السلة' : 'Failed to load cart',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCartItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
              child: Text(_isAr ? 'إعادة المحاولة' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
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
                color: _brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.shopping_cart,
                size: 52,
                color: _brand,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isAr ? 'سلتك فارغة' : 'Your cart is empty',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isAr
                  ? 'ابدأ بإضافة المنتجات إلى سلتك'
                  : 'Start adding products to your cart',
              style: TextStyle(
                color: context.appTextSecondary,
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

  Widget _buildGroupedList() {
    final groups = _groupedBySeller.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups[index];
        final sellerName = entry.value.first.seller.name;
        final items = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Row(
                children: [
                  Icon(
                    Iconsax.shop,
                    size: 18,
                    color: context.appTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sellerName.isNotEmpty
                          ? sellerName
                          : (_isAr ? 'بائع' : 'Seller'),
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...items.map(_buildCartItem),
          ],
        );
      },
    );
  }

  Widget _buildCartItem(CartItemModel cartItem) {
    final unitPrice = double.tryParse(cartItem.item.price) ?? 0;
    final lineTotal = unitPrice * cartItem.cartQuantity;
    final currency = _isAr ? 'ريال' : 'QAR';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
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
              width: 76,
              height: 76,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cartItem.seller.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${unitPrice.toStringAsFixed(2)} $currency',
                  style: const TextStyle(
                    color: _brand,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QuantityStepper(
                      quantity: cartItem.cartQuantity,
                      maxQuantity: cartItem.item.availableQuantity,
                      onAdd: () {
                        if (cartItem.cartQuantity <
                            cartItem.item.availableQuantity) {
                          _updateQuantity(
                            cartItem,
                            cartItem.cartQuantity + 1,
                          );
                        }
                      },
                      onRemove: () => _updateQuantity(
                        cartItem,
                        cartItem.cartQuantity - 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${lineTotal.toStringAsFixed(2)} $currency',
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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

  Widget _buildBottomSummary() {
    final currency = _isAr ? 'ريال' : 'QAR';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkElevated
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow(
              _isAr ? 'المجموع الفرعي' : 'Subtotal',
              '${_subtotal.toStringAsFixed(2)} $currency',
            ),
            const SizedBox(height: 10),
            Divider(color: context.appBorder, height: 1),
            const SizedBox(height: 10),
            _summaryRow(
              _isAr ? 'الإجمالي' : 'Total',
              '${_total.toStringAsFixed(2)} $currency',
              emphasize: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cartItems.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderSummaryScreen(
                              userId: widget.userId,
                              cartItems: List<CartItemModel>.from(_cartItems),
                              totalAmount: _total,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) _loadCartItems();
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _brand.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _isAr ? 'متابعة الدفع' : 'Proceed to checkout',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool emphasize = false,
    bool muted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: muted
                ? context.appTextSecondary
                : context.appTextPrimary,
            fontSize: emphasize ? 17 : 14,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasize
                ? _brand
                : (muted
                    ? context.appTextSecondary
                    : context.appTextPrimary),
            fontSize: emphasize ? 17 : 14,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final int maxQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QuantityStepper({
    required this.quantity,
    required this.maxQuantity,
    required this.onAdd,
    required this.onRemove,
  });

  static const Color _brand = Color(0xFF5C33EA);

  @override
  Widget build(BuildContext context) {
    final canAdd = quantity < maxQuantity;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _brand,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(
            icon: quantity <= 1 ? Iconsax.trash : Iconsax.minus,
            onTap: onRemove,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          _stepBtn(
            icon: Iconsax.add,
            onTap: canAdd ? onAdd : null,
            dimmed: !canAdd,
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    VoidCallback? onTap,
    bool dimmed = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 34,
        height: 36,
        child: Icon(
          icon,
          size: 18,
          color: Colors.white.withValues(alpha: dimmed ? 0.4 : 1),
        ),
      ),
    );
  }
}
