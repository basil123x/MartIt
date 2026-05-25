import '../utils/product_image_url.dart';

class CartItemModel {
  final String cartId;
  final String orderId;
  int cartQuantity;
  final CartItem item;
  final CartSeller seller;

  CartItemModel({
    required this.cartId,
    required this.orderId,
    required this.cartQuantity,
    required this.item,
    required this.seller,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      cartId: json['cart_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      cartQuantity: json['cart_quantity'] ?? 0,
      item: CartItem.fromJson(json['item'] ?? {}),
      seller: CartSeller.fromJson(json['seller'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cart_id': cartId,
      'order_id': orderId,
      'cart_quantity': cartQuantity,
      'item': item.toJson(),
      'seller': seller.toJson(),
    };
  }
}

class CartItem {
  final String id;
  final String idx;
  final String name;
  final String price;
  final int availableQuantity;
  final String thumbnail;
  final String store_id;

  CartItem({
    required this.id,
    required this.idx,
    required this.name,
    required this.price,
    required this.availableQuantity,
    required this.thumbnail,
    required this.store_id,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final idx = (json['idx'] ?? '').toString();
    final storeId = json['store_id']?.toString() ?? '4';
    final thumb = json['thumbnail']?.toString() ?? '';
    final thumbnail = ProductImageUrl.isAlbadaaStore(storeId)
        ? ProductImageUrl.albadaaImageUrl(idx: idx, id: id)
        : (thumb.isNotEmpty
            ? thumb
            : ProductImageUrl.build(
                storeId: storeId,
                itemId: id,
                itemIdx: idx,
              ));
    return CartItem(
      id: id,
      idx: idx,
      name: json['name']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      availableQuantity: json['available_quantity'] ?? 0,
      thumbnail: thumbnail,
      store_id: storeId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idx': idx,
      'name': name,
      'price': price,
      'available_quantity': availableQuantity,
      'thumbnail': thumbnail,
      'store_id': store_id,
    };
  }
}

class CartSeller {
  final String id;
  final String name;

  CartSeller({required this.id, required this.name});

  factory CartSeller.fromJson(Map<String, dynamic> json) {
    return CartSeller(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
