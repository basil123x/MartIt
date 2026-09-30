import 'package:flutter/material.dart';

import 'cart_screen.dart';

/// Legacy entry point — delegates to [CartScreen].
class ShoppingCartScreen extends StatelessWidget {
  final String userId;

  const ShoppingCartScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return CartScreen(userId: userId);
  }
}
