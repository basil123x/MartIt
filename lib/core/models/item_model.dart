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

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    // Parse media from database format (e.g., "1.jpg, 2.jpg, 3.mp4")
    List<String> mediaList = [];
    if (json['media'] != null && json['media'].toString().isNotEmpty) {
      final mediaString = json['media'].toString();
      final mediaFiles = mediaString
          .split(', ')
          .map((file) => file.trim())
          .toList();

      // Convert to full URLs
      for (String file in mediaFiles) {
        if (file.isNotEmpty) {
          final itemId = json['id'].toString();
          final fullUrl = 'https://globee.b-cdn.net/$itemId/$file';
          mediaList.add(fullUrl);
        }
      }
    }

    return ItemModel(
      id: json['id'].toString(),
      idx: json['idx'].toString(),
      storeid: json['storeid'].toString(),
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

  UserProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    required this.uid,
    required this.avatar,
    required this.itemsCount,
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
