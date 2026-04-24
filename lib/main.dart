import 'dart:async';
import 'dart:io';

import 'package:MartIt/core/services/google_auth_service.dart';
import 'package:MartIt/features/chat/chat_screen.dart';
import 'package:MartIt/shared/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:terminate_restart/terminate_restart.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/splash/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleAuthService().initialize();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  OneSignal.initialize("ddec3249-5f16-4870-9c32-682a704559b6");
  await OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addClickListener((event) {
    print('OneSignal: notification clicked: ${event.notification.title}');

    // استخرج البيانات من الـ notification
    final additionalData = event.notification.additionalData;

    if (additionalData != null) {
      final sellerId = additionalData['receiverId'];
      final sellerName = additionalData['receiverName'] ?? 'Unknown';
      final sellerAvatar = additionalData['receiverAvatar'] ?? '';
      final sellerToken = additionalData['receiverToken'] ?? '';
      final convers = additionalData['conversationId'] ?? '';

      // استخدام navigatorKey للـ navigation
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverId: sellerId,
            receiverName: sellerName,
            receiverAvatar: sellerAvatar,
            receiverToken: sellerToken,
            conversationId: convers,
            isOnline: false,
          ),
        ),
      );
    }
  });

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    print('OneSignal: notification received: ${event.notification.title}');
    event.preventDefault();
    event.notification.display();
  });

  runApp(const MartItApp());
}

class MartItApp extends StatefulWidget {
  const MartItApp({super.key});

  @override
  State<MartItApp> createState() => _MartItAppState();
}

class _MartItAppState extends State<MartItApp> {
  final updater = ShorebirdUpdater();
  Timer? _timer;
  static const _lastPatchKey = "last_applied_patch";

  Future<void> ensureDoubleRestart() async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final lastPatchNumber = prefs.getInt(_lastPatchKey) ?? 0;
    final currentPatch = await updater.readCurrentPatch();

    if (currentPatch != null && currentPatch.number != lastPatchNumber) {
      await prefs.setInt(_lastPatchKey, currentPatch.number);
      await Future.delayed(const Duration(seconds: 2));
      if (Platform.isIOS) {
        Restart.restartApp();
      } else {
        await TerminateRestart.instance.restartApp(
          options: const TerminateRestartOptions(terminate: true),
        );
      }
    }
  }

  Future<void> checkForUpdates() async {
    final status = await updater.checkForUpdate();

    if (status == UpdateStatus.outdated) {
      try {
        await updater.update();
        final prefs = await SharedPreferences.getInstance();
        final currentPatch = await updater.readCurrentPatch();
        if (currentPatch != null) {
          await prefs.setInt(_lastPatchKey, currentPatch.number - 1);
        }

        if (Platform.isIOS) {
          Restart.restartApp(
            notificationTitle: "إشعار هام",
            notificationBody: "قم بتحديث التطبيق الأن",
          );
        } else {
          await TerminateRestart.instance.restartApp(
            options: const TerminateRestartOptions(terminate: true),
          );
        }
      } on UpdateException catch (error) {
        print("Update failed: $error");
      }
    }
  }

  @override
  void initState() {
    ensureDoubleRestart();
    checkForUpdates();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      checkForUpdates();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider())],
      child: MaterialApp(
        title: AppStrings.appName,
        theme: AppTheme.lightTheme,
        navigatorKey: navigatorKey,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}
