import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InvoiceWebView extends StatefulWidget {
  final String url;
  const InvoiceWebView({super.key, required this.url});

  @override
  State<InvoiceWebView> createState() => _InvoiceWebViewState();
}

class _InvoiceWebViewState extends State<InvoiceWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          // ✅ هذا هو المفتاح - يضبط الـ viewport عشان الصفحة تجي كاملة
          _controller.runJavaScript('''
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = 'viewport';
              document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
          ''');
          setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفاتورة'),
        backgroundColor: const Color(0xFF1A6BB5),
        foregroundColor: Colors.white,
        bottom: PreferredSize(preferredSize: Size(double.maxFinite, 2), child: Divider(color: Color(0xFF0D4A8A),)),
        actions: [
          // زر ريفريش
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}