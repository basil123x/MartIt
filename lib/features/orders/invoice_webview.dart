import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/localization_service.dart';

/// In-app WebView fallback when invoice HTML is only available from the server.
class InvoiceWebView extends StatefulWidget {
  final String url;
  final String? title;

  const InvoiceWebView({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<InvoiceWebView> createState() => _InvoiceWebViewState();
}

class _InvoiceWebViewState extends State<InvoiceWebView> {
  static const Color _brand = Color(0xFF5C33EA);
  static const Color _titleColor = Color(0xFF1A1333);

  late final WebViewController _controller;
  bool _isLoading = true;

  bool get _isAr => LocalizationService.instance.currentLanguage == 'ar';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            _controller.runJavaScript('''
              var meta = document.querySelector('meta[name="viewport"]');
              if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
              }
              meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
            ''');
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Rect _shareOriginFor(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size != Size.zero) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(0, 0, size.width, size.height / 2);
  }

  Future<void> _share(BuildContext buttonContext) async {
    await Share.share(
      widget.url,
      subject: _isAr ? 'فاتورتك' : 'Your invoice',
      sharePositionOrigin: _shareOriginFor(buttonContext),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : _titleColor;
    final title = widget.title ?? (isAr ? 'فاتورتك' : 'Your invoice');

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
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
            title,
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
                  onPressed: () => _share(buttonContext),
                  tooltip: isAr ? 'مشاركة' : 'Share',
                  icon: Icon(Iconsax.share, color: titleColor),
                );
              },
            ),
            IconButton(
              onPressed: () => _controller.reload(),
              tooltip: isAr ? 'تحديث' : 'Refresh',
              icon: Icon(Iconsax.refresh, color: titleColor),
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: _brand),
              ),
          ],
        ),
      ),
    );
  }
}
