import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows the OTP in a local notification (no SMS/WhatsApp provider).
class OtpLocalNotificationService {
  OtpLocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'martit_otp_channel',
    'OTP Messages',
    description: 'OTP verification messages',
    importance: Importance.high,
  );

  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    }

    _initialized = true;
  }

  static Future<void> showOtpNotification({
    required String otp,
    String title = 'MartIt',
  }) async {
    try {
      await ensureInitialized();
      final body = 'MartIt: رمز التحقق الخاص بك هو $otp';
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {
      // Never block the OTP flow.
    }
  }
}
