import 'dart:convert';
import 'package:Globee/core/models/item_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://www.Globee-Trading.com/app2026';

  // Test server connection
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/test.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection test failed: $e');
    }
  }

  // Fetch items with pagination for infinite scroll
  // Fetch items with pagination for infinite scroll
  static Future<List<ItemModel>> fetchItems({
    required int page,
    String? userId, // ✅ أضفنا userId parameter
  }) async {
    try {
      final url = Uri.parse('$baseUrl/sql.php');

      // ✅ نبعت user_id لو موجود
      final body = {'action': 'fetch', 'page': page.toString(), 'limit': '10'};

      // ✅ لو في user_id، نضيفه للـ body
      if (userId != null && userId.isNotEmpty) {
        body['user_id'] = userId;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("SSSSS $data");

        if (data['success'] == true) {
          final List<dynamic> itemsJson = data['data'];
          return itemsJson.map((json) => ItemModel.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? 'فشل في جلب البيانات');
        }
      } else {
        throw Exception('خطأ في الاتصال بالخادم: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching items: $e');
      throw Exception('فشل في جلب البيانات: $e');
    }
  }

  // Search items by name
  static Future<Map<String, dynamic>> searchItems(String query) async {
    try {
      final response = await Dio().get(
        '$baseUrl/search.php?q=$query',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to search items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Search error: $e');
    }
  }

  // Get user profile
  static Future getUserProfile(int userId) async {
    try {
      final response = await Dio().get(
        '$baseUrl/profile.php?user_id=$userId&k=${DateTime.now().millisecondsSinceEpoch}',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Profile error: $e');
    }
  }

  static Future getUserProfileItems(int userId) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "fetch_items_one_account",
          "uid": userId,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Profile error: $e');
    }
  }

  // Get comments for item
  static Future<Map<String, dynamic>> getComments(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comments.php?item_id=$itemId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load comments: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Comments error: $e');
    }
  }

  // Add comment to item
  static Future<Map<String, dynamic>> addComment({
    required int itemId,
    required int userId,
    required String comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comments.php?item_id=$itemId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'comment': comment, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add comment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Add comment error: $e');
    }
  }

  // Get item statistics
  static Future<Map<String, dynamic>> getItemStats(String itemId) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php',
        data: FormData.fromMap({"action": "get_stats", "item_id": itemId}),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Stats error: $e');
    }
  }

  // Add report
  static Future<Map<String, dynamic>> addReport({
    required String itemId,
    required String userId,
    required String reason,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php',
        data: FormData.fromMap({
          "action": "add_report",
          "item_id": itemId,
          "user_id": userId,
          "reason": reason,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to add report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Report error: $e');
    }
  }

  // Toggle like
  static Future<Map<String, dynamic>> toggleLike({
    required String itemId,
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php',
        data: FormData.fromMap({
          "action": "toggle_like",
          "item_id": itemId,
          "user_id": userId,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to toggle like: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Like error: $e');
    }
  }

  // Add to cart
  static Future<Map<String, dynamic>> addToCart({
    required String itemId,
    required String userId,
    int quantity = 1,
  }) async {
    try {
      String? oid = await FlutterSecureStorage().read(key: "user_oid");
      final response = await Dio().post(
        '$baseUrl/sql.php',
        data: FormData.fromMap({
          "action": "add_to_cart",
          "item_id": itemId,
          "user_id": userId,
          "oid": oid,
          "quantity": quantity.toString(),
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to add to cart: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Cart error: $e');
    }
  }

  // Remove from cart
  static Future<Map<String, dynamic>> removeFromCart({
    required String itemId,
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php',
        data: FormData.fromMap({
          "action": "remove_from_cart",
          "item_id": itemId,
          "user_id": userId,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to remove from cart: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Cart error: $e');
    }
  }

  // Get cart quantity
  static Future<Map<String, dynamic>> getCartQuantity({
    required String itemId,
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php',
        data: FormData.fromMap({
          "action": "get_cart_quantity",
          "item_id": itemId,
          "user_id": userId,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get cart quantity: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Cart error: $e');
    }
  }

  // Fetch items with likes status
  static Future<List<ItemModel>> fetchItemsWithLikes({
    required String userId,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php',
        data: FormData.fromMap({
          "action": "fetch_with_likes",
          "user_id": userId,
          "limit": limit.toString(),
          "offset": offset.toString(),
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final List<dynamic> itemsData = data['data'] ?? [];
          return itemsData.map((item) {
            // Create ItemModel with likes data
            final itemModel = ItemModel.fromJson(item);
            // Update interactions with server data
            itemModel.interactions.likes = item['likes_count'] ?? 0;
            itemModel.interactions.isLiked = item['is_liked'] ?? false;
            // Update seller following status from seller data
            if (item['seller'] != null &&
                item['seller']['isFollowing'] != null) {
              itemModel.seller.isFollowing = item['seller']['isFollowing'];
            }
            return itemModel;
          }).toList();
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch items');
        }
      } else {
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Fetch error: $e');
    }
  }
}
