import '../constants/app_constants.dart';
import '../utils/product_image_url.dart';

class ItemModel {
  final String id;
  final String idx;
  final String storeid;
  final String name;
  final String price;
  final int quantity;
  final String description;
  final int views;
  final List<String> media;
  final SellerModel seller;
  final InteractionsModel interactions;

  ItemModel({
    required this.id,
    required this.idx,
    required this.storeid,
    required this.name,
    required this.price,
    required this.quantity,
    required this.description,
    required this.views,
    required this.media,
    required this.seller,
    required this.interactions,
  });

  String get primaryImageUrl => ProductImageUrl.isAlbadaaStore(storeid)
      ? ProductImageUrl.albadaaImageUrl(idx: idx, id: id)
      : ProductImageUrl.build(
          storeId: storeid.isNotEmpty ? storeid : '4',
          itemId: id,
          itemIdx: idx,
        );

  /// URLs for feed (store_4: martit store_4/{idx}/N.png).
  List<String> get feedMediaUrls => ProductImageUrl.feedMediaUrls(
        storeId: storeid,
        itemId: id,
        itemIdx: idx,
        apiMedia: media,
      );

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    final itemId = json['id'].toString();
    final itemIdx = (json['idx'] ?? '').toString();
    final storeId =
        (json['storeid'] ?? json['store_id'] ?? AppConstants.albadaaStoreId)
            .toString();
    final mediaField = _mediaFieldFromJson(json['media']);

    List<String> mediaList;
    if (ProductImageUrl.isAlbadaaStore(storeId)) {
      mediaList = ProductImageUrl.albadaaMediaUrls(
        idx: itemIdx,
        id: itemId,
        mediaField: mediaField,
      );
    } else if (json['media'] is List) {
      final raw = (json['media'] as List).map((e) => e.toString()).toList();
      if (raw.isNotEmpty && raw.first.startsWith('http')) {
        mediaList = raw;
      } else {
        mediaList = ProductImageUrl.mediaList(
          storeId: storeId,
          itemId: itemId,
          itemIdx: itemIdx,
          mediaField: mediaField,
        );
      }
    } else {
      mediaList = ProductImageUrl.mediaList(
        storeId: storeId,
        itemId: itemId,
        itemIdx: itemIdx,
        mediaField: mediaField,
      );
    }

    return ItemModel(
      id: itemId,
      idx: itemIdx,
      storeid: storeId,
      name: json['name'] ?? '',
      price: json['price']?.toString() ?? '0',
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      description: json['description'] ?? '',
      views: int.tryParse(json['views']?.toString() ?? '0') ?? 0,
      media: mediaList,
      seller: SellerModel.fromJson({
        'id': json['seller']['id'] ?? '',
        'uid': json['seller']['uid'] ?? '',
        'name': json['seller']['name'] ?? 'مستخدم',
        'avatar': json['seller']['avatar'] ?? '',
        'token': json['seller']['token'] ?? '',
      }),
      interactions: InteractionsModel.fromJson(json['interactions'] ?? {}),
    );
  }

  static String? _mediaFieldFromJson(dynamic media) {
    if (media == null) return null;
    if (media is List) {
      final parts = media.map((e) => e.toString().trim()).toList();
      if (parts.isEmpty) return null;
      if (parts.first.startsWith('http')) {
        return List<String>.generate(parts.length, (i) => '${i + 1}.png')
            .join(', ');
      }
      return parts.join(', ');
    }
    return media.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idx': idx,
      'storeid': storeid,
      'name': name,
      'price': price,
      'quantity': quantity,
      'description': description,
      'views': views,
      'media': media,
      'seller': seller.toJson(),
      'interactions': interactions.toJson(),
    };
  }
}

class SellerModel {
  final String id;
  final String uid;
  final String name;
  final String avatar;
  String token;
  bool isFollowing;

  SellerModel({
    required this.id,
    required this.uid,
    required this.name,
    required this.avatar,
    this.token = "",
    this.isFollowing = false,
  });

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    return SellerModel(
      id: json['id']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      token: json['token'] ?? '',
      isFollowing: json['isFollowing'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'uid': uid, 'name': name, 'avatar': avatar};
  }
}

class InteractionsModel {
  int likes;
  int comments;
  int shares;
  int cartQuantity;
  bool isLiked;

  InteractionsModel({
    required this.likes,
    required this.comments,
    required this.shares,
    required this.cartQuantity,
    this.isLiked = false,
  });

  factory InteractionsModel.fromJson(Map<String, dynamic> json) {
    return InteractionsModel(
      likes: int.tryParse(json['likes']?.toString() ?? '0') ?? 0,
      comments: int.tryParse(json['comments']?.toString() ?? '0') ?? 0,
      shares: int.tryParse(json['shares']?.toString() ?? '0') ?? 0,
      cartQuantity: int.tryParse(json['cartQuantity']?.toString() ?? '0') ?? 0,
      isLiked: json['isLiked'] == true || json['isLiked'] == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'cartQuantity': cartQuantity,
      'isLiked': isLiked,
    };
  }
}

class CommentModel {
  final String id;
  final String userName;
  final String userAvatar;
  final String comment;
  final String createdAt;

  CommentModel({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.comment,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id']?.toString() ?? '',
      userName: json['user_name'] ?? json['userName'] ?? json['name'] ?? '',
      userAvatar: json['user_avatar'] ?? json['userAvatar'] ?? json['avatar'] ?? '',
      comment: json['comment'] ?? json['text'] ?? json['content'] ?? '',
      createdAt: json['created_at'] ?? json['createdAt'] ?? json['created_atx'] ?? '',
    );
  }
}

class UserProfileModel {
  final String id;
  final String name;
  final String phone;
  final String type;
  final String uid;
  final String avatar;
  final int itemsCount;
  final String role;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    required this.uid,
    required this.avatar,
    required this.itemsCount,
    required this.role,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      type: json['type'] ?? '',
      uid: json['uid'] ?? '',
      avatar: json['avatar'] ?? '',
      itemsCount: int.tryParse(json['itemsCount']?.toString() ?? '0') ?? 0,
      role: json['role'] ?? '',
    );
  }
}

class UserProfileItemsModel {
  final String id;
  final String name;
  final String price;
  final int views;
  final List<String> media;

  UserProfileItemsModel({
    required this.id,
    required this.name,
    required this.price,
    required this.views,
    required this.media,
  });

  factory UserProfileItemsModel.fromJson(Map<String, dynamic> json) {
    return UserProfileItemsModel(
      id: json['id'].toString(),
      name: json['name'],
      price: json['price'],
      views: int.tryParse(json['views'].toString()) ?? 0,
      media: json['media'],
    );
  }
}
