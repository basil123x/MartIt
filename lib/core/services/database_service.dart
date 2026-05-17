import 'package:dio/dio.dart';

class DatabaseService {
  static const String _baseUrl = 'https://www.Globee-Trading.com/app2026';
  static final Dio _dio = Dio();

  static Future<Map<String, dynamic>> createItem(String userId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({'action': 'create_item', 'user_id': userId}),
      );

      return response.data;
    } catch (e) {
      print('Error creating item: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateItem({
    required String itemId,
    required String uid,
    required String barcode,
    required String name,
    required String eng,
    required String description,
    required String description_arb,
    required String category,
    required String price,
    required String quantity,
    required String visibility,
    required String comments,
    required String media,
    int? idx,
    int? clientId,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'action': 'insert',
        'item_id': itemId,
        'uid': uid,
        'barcode': barcode,
        'name': name,
        'eng': eng,
        'description': description,
        'description_arb': description_arb,
        'category': category,
        'price': price,
        'qtt': quantity,
        'visibility': visibility,
        'comments': comments,
        'media': media,
        'store_id': '2',
      };
      if (idx != null && idx > 0) {
        payload['idx'] = idx.toString();
      }
      if (clientId != null && clientId > 0) {
        payload['client_id'] = clientId.toString();
      }
      final response = await _dio.post(
        '$_baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(payload),
      );

      return response.data;
    } catch (e) {
      print('Error updating item: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> followUser({
    required String buyerId,
    required String userId,
    String? userToken,
  }) async {
    try {
      final url = '$_baseUrl/sql.php';

      final response = await Dio().post(
        url,
        data: {
          'action': 'follow_user',
          'buyer_id': buyerId,
          'user_id': userId,
          'user_token': userToken ?? '',
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data;
      } else {
        return {
          'success': false,
          'error': 'خطأ في الاتصال بالخادم: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error in followUser: $e');
      return {'success': false, 'error': 'فشل في الاتصال بالخادم'};
    }
  }

  static Future<Map<String, dynamic>> getItems({int page = 0}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'get_items',
          'page': page.toString(),
        }),
      );

      return response.data;
    } catch (e) {
      print('Error getting items: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
