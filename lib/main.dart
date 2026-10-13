import 'dart:async';
import 'dart:io';

import 'package:MartIt/features/chat/chat_screen.dart';
import 'package:MartIt/shared/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'core/services/api_config_service.dart';
import 'core/services/localization_service.dart';
import 'core/services/shorebird_update_service.dart';
import 'core/services/store_update_service.dart';
import 'features/splash/splash_screen.dart';
import 'features/update/update_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  String appToken = "";
  if (Platform.isIOS) {
    appToken = "5f910d9c-d0cd-4171-b2b2-94f68636d7de";
  } else {
    appToken = "ddec3249-5f16-4870-9c32-682a704559b6";
  }
  OneSignal.initialize(appToken);
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

  await LocalizationService.instance.init();

  // Load remote API domain and store-update config.
  await ApiConfigService.instance.init();

  final storeUpdate = await StoreUpdateService.instance.check();
  if (storeUpdate == null) {
    final restarting = await ShorebirdUpdateService.instance.sync();
    if (restarting) return;
  }

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool(AppProvider.darkModeKey) ?? false;

  runApp(MartItApp(initialDarkMode: isDark, forcedUpdate: storeUpdate));
}

class MartItApp extends StatefulWidget {
  final bool? initialDarkMode;
  final StoreUpdateRequirement? forcedUpdate;

  const MartItApp({super.key, this.initialDarkMode, this.forcedUpdate});

  @override
  State<MartItApp> createState() => _MartItAppState();
}

class _MartItAppState extends State<MartItApp> with WidgetsBindingObserver {
  Timer? _timer;
  bool _showingForceUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showingForceUpdate = widget.forcedUpdate != null;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _watchForUpdates();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watchForUpdates();
    }
  }

  Future<void> _watchForUpdates() async {
    if (_showingForceUpdate) return;
    await ApiConfigService.instance.refreshFromRemote();
    final requirement = await StoreUpdateService.instance.check();
    if (requirement != null) {
      _openForceUpdate(requirement);
      return;
    }
    final restarting = await ShorebirdUpdateService.instance.sync();
    if (restarting) return;
  }

  void _openForceUpdate(StoreUpdateRequirement requirement) {
    final nav = navigatorKey.currentState;
    if (nav == null || _showingForceUpdate) return;
    _showingForceUpdate = true;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ForceUpdateScreen(
          message: requirement.message,
          storeUrl: requirement.storeUrl,
          currentVersion: requirement.currentVersion,
          latestVersion: requirement.latestVersion,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: LocalizationService.instance),
        ChangeNotifierProvider(
          create: (_) {
            final provider = AppProvider(
              initialDarkMode: widget.initialDarkMode,
            );
            provider.loadPreferences();
            return provider;
          },
        ),
      ],
      child: Consumer2<LocalizationService, AppProvider>(
        builder: (context, localization, appProvider, _) {
          return MaterialApp(
            title: AppStrings.appName,
            theme: AppTheme.lightTheme,
            navigatorKey: navigatorKey,
            darkTheme: AppTheme.darkTheme,
            themeMode: appProvider.themeMode,
            debugShowCheckedModeBanner: false,
            locale: Locale(localization.currentLanguage),
            builder: (context, child) {
              return Directionality(
                textDirection: localization.textDirection,
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Cairo',
                  ),
                  child: child!,
                ),
              );
            },
            home: widget.forcedUpdate == null
                ? const SplashScreen()
                : ForceUpdateScreen(
                    message: widget.forcedUpdate!.message,
                    storeUrl: widget.forcedUpdate!.storeUrl,
                    currentVersion: widget.forcedUpdate!.currentVersion,
                    latestVersion: widget.forcedUpdate!.latestVersion,
                  ),
          );
        },
      ),
    );
  }
}
