import "dart:io";

import "package:awesome_dialog/awesome_dialog.dart";
import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:iconsax/iconsax.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../../core/constants/app_colors.dart";
import "../../core/constants/app_theme.dart";
import "../../core/models/item_model.dart";
import "../../core/services/auth_service.dart";
import "../../core/utils/snackbar_helper.dart";
import "../../core/utils/theme_extensions.dart";
import "../../shared/providers/app_provider.dart";
import "../auth/login.dart";
import "../onboarding/language_selection_screen.dart";
import "../profile/edit_profile_screen.dart";
import "policy_screen.dart";
import '../../core/services/api_config_service.dart';

class SettingsScreen extends StatefulWidget {
  final UserProfileModel? profile;

  const SettingsScreen({super.key, this.profile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _storage = FlutterSecureStorage();

  String _appVersion = "";
  String _loginType = "";
  UserProfileModel? _profile;

  static String get _privacyUrl =>
      ApiConfigService.instance.endpoint('PrivacyPolicy.php');
  static String get _termsUrl =>
      ApiConfigService.instance.endpoint('Terms.php');

  // TODO: Replace with the real App Store numeric ID once MartIt is live
  // on the App Store (e.g. "1234567890"). Leave empty until published.
  static const String appStoreId = "";

  // TODO: Replace with the real Google Play package name once MartIt is live
  // on Google Play (e.g. "com.mazo.market"). Leave empty until published.
  // Note: android/app/build.gradle.kts currently has applicationId
  // "com.mazo.market", but that alone does not mean the store listing exists.
  static const String androidPackageName = "";

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadVersion();
    _loadLoginType();
  }

  Future<void> _loadLoginType() async {
    final loginType = await _storage.read(key: "login_type") ?? "";
    if (!mounted) return;
    setState(() => _loginType = loginType);
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
    });
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          currentName: profile.name,
          currentPhone: profile.phone,
          currentType: profile.type,
          currentAvatar: profile.avatar,
          currentUid: profile.uid,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _openPolicyPage({
    required String title,
    required String url,
  }) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PolicyScreen(title: title, url: url),
      ),
    );
  }

  Future<void> _rateApp() async {
    final isIos = !kIsWeb && Platform.isIOS;
    final storeId = isIos ? appStoreId.trim() : androidPackageName.trim();

    // Store listing not configured / app not published yet.
    if (storeId.isEmpty) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: "المتجر غير متاح حالياً",
        type: SnackType.info,
      );
      return;
    }

    final url = isIos
        ? "https://apps.apple.com/app/id$storeId?action=write-review"
        : "https://play.google.com/store/apps/details?id=$storeId&showAllReviews=true";

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showAppSnackbar(
        context,
        message: "المتجر غير متاح حالياً",
        type: SnackType.info,
      );
    }
  }

  Future<void> _openLanguageSelection() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LanguageSelectionScreen(fromSettings: true),
      ),
    );
    // Language subtitle rebuilds via AppProvider / LocalizationService.
    if (mounted) setState(() {});
  }

  void _logout() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: "تسجيل الخروج",
      desc: "هل أنت متأكد أنك تريد تسجيل الخروج؟",
      btnCancelText: "إلغاء",
      btnOkText: "تسجيل الخروج",
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        await AuthService.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      },
    ).show();
  }

  void _deleteAccount() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: "حذف الحساب",
      desc:
          "هل أنت متأكد؟ هذا الإجراء لا يمكن التراجع عنه وسيتم حذف جميع بياناتك نهائياً.",
      btnCancelText: "إلغاء",
      btnOkText: "حذف نهائياً",
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final uid = await AuthService.getCurrentUID();
        if (uid == null || uid.isEmpty) {
          _showSnack("تعذر تحديد المستخدم", isError: true);
          return;
        }

        try {
          final response = await Dio().post(
            "${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
            data: FormData.fromMap({
              "action": "delete_account_permit",
              "uid": uid,
            }),
          );

          if (response.data["success"] == true) {
            await AuthService.logout();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          } else {
            _showSnack(
              response.data["error"]?.toString() ?? "فشل في حذف الحساب",
              isError: true,
            );
          }
        } catch (e) {
          _showSnack("حدث خطأ أثناء حذف الحساب", isError: true);
        }
      },
    ).show();
  }

  void _showSnack(String message, {bool isError = false}) {
    showAppSnackbar(
      context,
      message: message,
      type: isError ? SnackType.error : SnackType.success,
    );
  }

  Widget _sectionHeader(String title) {
    final muted = context.appTextSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: TextStyle(
            color: muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _settingsSection({required List<Widget> children}) {
    return ColoredBox(
      color: context.appSurface,
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(
    height: 1,
    thickness: 1,
    color: context.appDivider,
    indent: 16,
    endIndent: 16,
  );

  Widget _iconBadge({
    required IconData icon,
    Color? iconColor,
    Color? backgroundColor,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.appIconPillBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor ?? context.appPrimary, size: 20),
    );
  }

  Widget _listTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    Color? iconBg,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    final muted = context.appTextSecondary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _iconBadge(
        icon: icon,
        iconColor: iconColor,
        backgroundColor: iconBg,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? context.appTextPrimary,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: muted, fontSize: 13))
          : null,
      trailing: trailing,
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    final inactiveTrack = context.isDarkMode
        ? AppColors.darkElevated
        : AppColors.fieldBorder;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: _iconBadge(icon: icon),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: context.appTextPrimary,
          fontSize: 15,
        ),
      ),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: cs.primary,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: inactiveTrack,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            "الإعدادات",
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: cs.primary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionHeader("الحساب"),
            ),
            _settingsSection(
              children: [
                _listTile(
                  icon: Iconsax.edit,
                  title: "تعديل الملف الشخصي",
                  onTap: _profile != null ? _openEditProfile : null,
                ),
                if (_loginType == "Email") ...[
                  _divider(),
                  _listTile(
                    icon: Iconsax.lock,
                    title: "تغيير كلمة المرور",
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? AppColors.darkElevated
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "قريباً",
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionHeader("التفضيلات"),
            ),
            _settingsSection(
              children: [
                _switchTile(
                  icon: Iconsax.moon,
                  title: "الوضع الليلي",
                  value: appProvider.darkMode,
                  onChanged: (val) async {
                    await appProvider.setDarkMode(val);
                  },
                ),
                _divider(),
                _switchTile(
                  icon: Iconsax.notification,
                  title: "الإشعارات",
                  value: appProvider.notificationsEnabled,
                  onChanged: appProvider.setNotificationsEnabled,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.language_square,
                  title: "اللغة",
                  subtitle: appProvider.language == "ar"
                      ? "العربية"
                      : "English",
                  trailing: Icon(
                    Icons.chevron_left,
                    size: 22,
                    color: context.appTextSecondary,
                  ),
                  onTap: _openLanguageSelection,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionHeader("عن التطبيق"),
            ),
            _settingsSection(
              children: [
                _listTile(
                  icon: Iconsax.shield,
                  title: "سياسة الخصوصية",
                  onTap: () => _openPolicyPage(
                    title: "سياسة الخصوصية",
                    url: _privacyUrl,
                  ),
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.document,
                  title: "شروط الاستخدام",
                  onTap: () =>
                      _openPolicyPage(title: "شروط الاستخدام", url: _termsUrl),
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.star,
                  title: "تقييم التطبيق",
                  onTap: _rateApp,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.info_circle,
                  title: "الإصدار",
                  trailing: Text(
                    _appVersion.isNotEmpty ? _appVersion : "1.2.6",
                    style: TextStyle(color: context.appTextSecondary),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionHeader("الحساب"),
            ),
            _settingsSection(
              children: [
                _listTile(
                  icon: Iconsax.logout,
                  title: "تسجيل الخروج",
                  iconColor: AppColors.error,
                  iconBg: martIt.dangerBg,
                  titleColor: AppColors.error,
                  onTap: _logout,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.trash,
                  title: "حذف الحساب",
                  iconColor: AppColors.error,
                  iconBg: martIt.dangerBg,
                  titleColor: AppColors.error,
                  onTap: _deleteAccount,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
