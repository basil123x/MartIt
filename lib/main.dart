import 'package:Globee/shared/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    // لو عايز تعرض الـ notification حتى لو الـ app مفتوح:
    event.preventDefault(); // امنع العرض التلقائي
    event.notification.display(); // اعرضها بنفسك
  });

  runApp(const GlobeeApp());
}

class GlobeeApp extends StatelessWidget {
  const GlobeeApp({super.key});

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
