import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/shipping_address_model.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';

class InvoiceLineItem {
  final String name;
  final int quantity;
  final double unitPrice;

  const InvoiceLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => unitPrice * quantity;

  factory InvoiceLineItem.fromCartItem(CartItemModel item) {
    return InvoiceLineItem(
      name: item.item.name,
      quantity: item.cartQuantity,
      unitPrice: double.tryParse(item.item.price) ?? 0,
    );
  }
}

/// Native in-app invoice using structured order data (no external browser).
class InvoiceScreen extends StatefulWidget {
  final String invoiceNumber;
  final DateTime issuedAt;
  final String buyerName;
  final String buyerPhone;
  final String buyerAddress;
  final List<InvoiceLineItem> items;
  final double totalAmount;
  final String? shareUrl;

  const InvoiceScreen({
    super.key,
    required this.invoiceNumber,
    required this.issuedAt,
    required this.buyerName,
    required this.buyerPhone,
    required this.buyerAddress,
    required this.items,
    required this.totalAmount,
    this.shareUrl,
  });

  factory InvoiceScreen.fromCheckout({
    required String invoiceNumber,
    required List<CartItemModel> cartItems,
    required ShippingAddressModel shippingAddress,
    required double totalAmount,
    String? shareUrl,
  }) {
    return InvoiceScreen(
      invoiceNumber: invoiceNumber,
      issuedAt: DateTime.now(),
      buyerName: shippingAddress.fullname,
      buyerPhone: shippingAddress.mobile,
      buyerAddress: shippingAddress.formattedAddress,
      items: cartItems.map(InvoiceLineItem.fromCartItem).toList(),
      totalAmount: totalAmount,
      shareUrl: shareUrl,
    );
  }

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  static const Color _title = Color(0xFF1A1333);
  static const Color _muted = Color(0xFF6B6B80);
  static const Color _brand = Color(0xFF5C33EA);
  static const Color _border = Color(0xFFEDEAF7);
  static const Color _surfaceSoft = Color(0xFFF5F3FF);
  static const Color _iconBadge = Color(0xFFEAE5FC);

  final GlobalKey _shareButtonKey = GlobalKey();
  final GlobalKey _exportButtonKey = GlobalKey();
  final GlobalKey _invoiceCaptureKey = GlobalKey();
  bool _isExporting = false;

  bool get _isAr => LocalizationService.instance.currentLanguage == 'ar';

  Rect _shareOriginFor(BuildContext? buttonContext, GlobalKey fallbackKey) {
    final box = buttonContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size != Size.zero) {
      return box.localToGlobal(Offset.zero) & box.size;
    }

    final keyBox =
        fallbackKey.currentContext?.findRenderObject() as RenderBox?;
    if (keyBox != null && keyBox.hasSize && keyBox.size != Size.zero) {
      return keyBox.localToGlobal(Offset.zero) & keyBox.size;
    }

    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(0, 0, size.width, size.height / 2);
  }

  Future<void> _share(BuildContext buttonContext) async {
    final currency = _isAr ? 'ريال' : 'QAR';
    final buffer = StringBuffer()
      ..writeln(
        _isAr
            ? 'فاتورة رقم #${widget.invoiceNumber}'
            : 'Invoice #${widget.invoiceNumber}',
      )
      ..writeln(
        _isAr
            ? 'التاريخ: ${DateFormat('yyyy/MM/dd').format(widget.issuedAt)}'
            : 'Date: ${DateFormat('yyyy-MM-dd').format(widget.issuedAt)}',
      )
      ..writeln('${_isAr ? 'المشتري' : 'Buyer'}: ${widget.buyerName}')
      ..writeln('${_isAr ? 'الهاتف' : 'Phone'}: ${widget.buyerPhone}')
      ..writeln('${_isAr ? 'العنوان' : 'Address'}: ${widget.buyerAddress}')
      ..writeln('---');

    for (final item in widget.items) {
      buffer.writeln(
        '${item.name} × ${item.quantity} = ${item.subtotal.toStringAsFixed(2)} $currency',
      );
    }

    buffer
      ..writeln('---')
      ..writeln(
        '${_isAr ? 'الإجمالي' : 'Total'}: ${widget.totalAmount.toStringAsFixed(2)} $currency',
      );

    if (widget.shareUrl != null && widget.shareUrl!.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(widget.shareUrl);
    }

    await Share.share(
      buffer.toString(),
      subject: _isAr
          ? 'فاتورة #${widget.invoiceNumber}'
          : 'Invoice #${widget.invoiceNumber}',
      sharePositionOrigin: _shareOriginFor(buttonContext, _shareButtonKey),
    );
  }

  /// Exports a high-res image of the invoice (avoids pdf/xml dependency clashes).
  Future<void> _exportInvoiceImage(BuildContext buttonContext) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final boundary = _invoiceCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Invoice capture target missing');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode invoice image');
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/invoice_${widget.invoiceNumber}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _isAr
            ? 'فاتورة رقم #${widget.invoiceNumber}'
            : 'Invoice #${widget.invoiceNumber}',
        subject: _isAr
            ? 'فاتورة #${widget.invoiceNumber}'
            : 'Invoice #${widget.invoiceNumber}',
        sharePositionOrigin: _shareOriginFor(buttonContext, _exportButtonKey),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: _isAr
            ? 'تعذر تصدير الفاتورة'
            : 'Could not export invoice',
        type: SnackType.error,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final titleColor = isDark ? Colors.white : _title;
    final mutedColor = isDark ? AppColors.darkTextSecondary : _muted;
    final currency = isAr ? 'ريال' : 'QAR';
    final dateText = DateFormat(isAr ? 'yyyy/MM/dd' : 'yyyy-MM-dd').format(
      widget.issuedAt,
    );

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
            isAr ? 'فاتورتك' : 'Your invoice',
            style: TextStyle(
              color: titleColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            Builder(
              builder: (buttonContext) {
                return IconButton(
                  key: _exportButtonKey,
                  onPressed: _isExporting
                      ? null
                      : () => _exportInvoiceImage(buttonContext),
                  tooltip: isAr ? 'تصدير صورة' : 'Export image',
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _brand,
                          ),
                        )
                      : const Icon(
                          Iconsax.document_download,
                          color: _brand,
                        ),
                );
              },
            ),
            Builder(
              builder: (buttonContext) {
                return IconButton(
                  key: _shareButtonKey,
                  onPressed: () => _share(buttonContext),
                  tooltip: isAr ? 'مشاركة' : 'Share',
                  icon: Icon(Iconsax.share, color: titleColor),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: RepaintBoundary(
            key: _invoiceCaptureKey,
            child: ColoredBox(
              color: bg,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : _surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : _border,
                      ),
                    ),
                    child: Row(
                      children: [
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
                            Iconsax.receipt_2,
                            color: _brand,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr
                                    ? 'فاتورة رقم #${widget.invoiceNumber}'
                                    : 'Invoice #${widget.invoiceNumber}',
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAr ? 'التاريخ: $dateText' : 'Date: $dateText',
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'MartIt',
                          style: TextStyle(
                            color: _brand,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          isAr ? 'بيانات المشتري' : 'Buyer details',
                          Iconsax.user,
                          isDark: isDark,
                          titleColor: titleColor,
                        ),
                        const SizedBox(height: 12),
                        _infoRow(
                          Iconsax.profile_circle,
                          widget.buyerName,
                          titleColor,
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          Iconsax.call,
                          widget.buyerPhone,
                          titleColor,
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          Iconsax.location,
                          widget.buyerAddress,
                          titleColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          isAr ? 'تفاصيل الطلب' : 'Order details',
                          Iconsax.shopping_bag,
                          isDark: isDark,
                          titleColor: titleColor,
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(isAr, mutedColor, isDark),
                        const SizedBox(height: 6),
                        ...widget.items.map(
                          (item) => _itemRow(
                            item,
                            titleColor: titleColor,
                            mutedColor: mutedColor,
                            borderColor:
                                isDark ? AppColors.darkBorder : _border,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          color: isDark ? AppColors.darkBorder : _border,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              isAr ? 'المجموع الكلي' : 'Total',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? _brand.withValues(alpha: 0.2)
                                    : _iconBadge,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${widget.totalAmount.toStringAsFixed(2)} $currency',
                                style: const TextStyle(
                                  color: _brand,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _sectionCard({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : _border,
        ),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(
    String title,
    IconData icon, {
    required bool isDark,
    required Color titleColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? _brand.withValues(alpha: 0.2) : _iconBadge,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: _brand, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8B7AF0)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(bool isAr, Color muted, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : _surfaceSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              isAr ? 'المنتج' : 'Item',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isAr ? 'الكمية' : 'Qty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isAr ? 'السعر' : 'Price',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isAr ? 'الإجمالي' : 'Subtotal',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(
    InvoiceLineItem item, {
    required Color titleColor,
    required Color mutedColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              item.name,
              style: TextStyle(
                color: titleColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.unitPrice.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: TextStyle(color: mutedColor, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.subtotal.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: _brand,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
