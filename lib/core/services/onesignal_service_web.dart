import 'dart:convert';
import 'package:http/http.dart' as http;

class OneSignalServiceWebSys {
  // ✅ حط الـ REST API Key من OneSignal Dashboard
  // Settings → Keys & IDs → REST API Key
  static const String _restApiKey =
      "os_v2_app_4grlpynt7rawxelgql7kdjjvmyqfvvwui3uulz4xhytvtrrpz5rlcd6qfkqs35tdu5wqrj7z4tkbzt4u2lmmg5ipzjwspolgrurjjoi";
  static const String _appId = "e1a2b7e1-b3fc-416b-9166-82fea1a53566";
  static const String _apiUrl = "https://onesignal.com/api/v1/notifications";

  static const String androidChannelId = 'globalfarm_crowing_v2';
  static const String androidSound = 'crowing';
  static const String iosSound = 'crowing.caf';

  static Map<String, dynamic> _soundPayload() => {
        'existing_android_channel_id': androidChannelId,
        'android_sound': androidSound,
        'ios_sound': iosSound,
        'priority': 10,
      };

  /// ✅ بعت notification لـ Player ID واحد
  static Future<bool> sendNotificationToUser({
    required String playerId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_player_ids': [playerId],
          'headings': {'en': title, 'ar': title},
          'contents': {'en': message, 'ar': message},
          'data': data ?? {},
          ..._soundPayload(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent successfully!');
        print('Response: ${response.body}');
        return true;
      } else {
        print('❌ Error: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Exception: $e');
      return false;
    }
  }

  /// ✅ بعت notification لأكتر من user
  static Future<bool> sendNotificationToMultipleUsers({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_player_ids': playerIds, // ✅ List من الـ Player IDs
          'headings': {'en': title, 'ar': title},
          'contents': {'en': message, 'ar': message},
          'data': data ?? {},
          ..._soundPayload(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notifications sent successfully!');
        return true;
      } else {
        print('❌ Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception: $e');
      return false;
    }
  }

  /// ✅ بعت notification لكل المستخدمين
  static Future<bool> sendNotificationToAll({
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'included_segments': ['All'], // ✅ لكل المستخدمين
          'headings': {'en': title, 'ar': title},
          'contents': {'en': message, 'ar': message},
          'data': data ?? {},
          ..._soundPayload(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent to all users!');
        return true;
      } else {
        print('❌ Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception: $e');
      return false;
    }
  }

  /// ✅ بعت notification بـ Filter (مثلاً لمدينة معينة)
  static Future<bool> sendNotificationWithFilter({
    required String title,
    required String message,
    required String filterKey,
    required String filterValue,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'filters': [
            {
              'field': 'tag',
              'key': filterKey,
              'relation': '=',
              'value': filterValue,
            },
          ],
          'headings': {'en': title, 'ar': title},
          'contents': {'en': message, 'ar': message},
          'data': data ?? {},
          ..._soundPayload(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent with filter!');
        return true;
      } else {
        print('❌ Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception: $e');
      return false;
    }
  }
}
