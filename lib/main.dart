import 'dart:async';
import 'dart:io';

import 'package:Globee/shared/providers/app_provider.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  OneSignal.initialize("ddec3249-5f16-4870-9c32-682a704559b6");
  await OneSignal.Notifications.requestPermission(true);
  OneSignal.Notifications.addClickListener((event) {
    print('OneSignal: notification clicked: ${event.notification.title}');
    // هنا تقدر تعمل navigation للصفحة اللي عايزها
    // مثلاً لو في data في الـ notification:
    // String? pageId = event.notification.additionalData?['page_id'];
  });

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    print('OneSignal: notification received: ${event.notification.title}');
    event.preventDefault();
    event.notification.display();
  });

  runApp(const GlobeeApp());
}

class GlobeeApp extends StatefulWidget {
  const GlobeeApp({super.key});

  @override
  State<GlobeeApp> createState() => _GlobeeAppState();
}

class _GlobeeAppState extends State<GlobeeApp> {
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
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}
