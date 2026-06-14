import "package:flutter/material.dart";
import "package:onesignal_flutter/onesignal_flutter.dart";
import "package:shared_preferences/shared_preferences.dart";

class AppProvider extends ChangeNotifier {
  static const String darkModeKey = "dark_mode";
  static const String notificationsKey = "notifications_enabled";
  static const String languageKey = "app_language";

  AppProvider({bool? initialDarkMode}) {
    if (initialDarkMode != null) {
      _darkMode = initialDarkMode;
    }
  }

  List<String> allMedia = [];

  bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _language = "ar";
  bool _preferencesLoaded = false;

  bool get darkMode => _darkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  String get language => _language;
  bool get preferencesLoaded => _preferencesLoaded;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  void setMedia(String allMediax) {
    allMedia.add(allMediax);
    notifyListeners();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(darkModeKey) ?? false;
    _notificationsEnabled = prefs.getBool(notificationsKey) ?? true;
    _language = prefs.getString(languageKey) ?? "ar";
    _preferencesLoaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(darkModeKey, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationsKey, value);

    try {
      if (value) {
        await OneSignal.Notifications.requestPermission(true);
        await OneSignal.User.pushSubscription.optIn();
      } else {
        await OneSignal.User.pushSubscription.optOut();
      }
    } catch (e) {
      debugPrint("OneSignal toggle error: $e");
    }

    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(languageKey, value);
    notifyListeners();
  }
}
