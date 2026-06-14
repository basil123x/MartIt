import "package:awesome_dialog/awesome_dialog.dart";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:iconsax/iconsax.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

import "../../core/constants/app_colors.dart";
import "../../core/models/item_model.dart";
import "../../core/services/auth_service.dart";
import "../../core/utils/snackbar_helper.dart";
import '../../core/utils/theme_extensions.dart';
import "../../shared/providers/app_provider.dart";
import "../auth/login.dart";
import "../profile/edit_profile_screen.dart";

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

  static const _privacyUrl =
      "https://www.Globee-Trading.com/app2026/PrivacyPolicy.php";
  static const _termsUrl = "https://www.Globee-Trading.com/app2026/Terms.php";

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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _rateApp() async {
    final info = await PackageInfo.fromPlatform();
    final androidUrl =
        "https://play.google.com/store/apps/details?id=${info.packageName}";
    final iosUrl = "https://apps.apple.com/app/id0000000000";
    final url = Theme.of(context).platform == TargetPlatform.iOS
        ? iosUrl
        : androidUrl;
    await _openUrl(url);
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

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Consumer<AppProvider>(
        builder: (context, appProvider, _) => Container(
        decoration: BoxDecoration(
          color: sheetContext.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "اختر اللغة",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text("العربية"),
              trailing: appProvider.language == "ar"
                  ? const Icon(Iconsax.tick_circle, color: AppColors.primary)
                  : null,
              onTap: () {
                appProvider.setLanguage("ar");
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("English"),
              trailing: appProvider.language == "en"
                  ? const Icon(Iconsax.tick_circle, color: AppColors.primary)
                  : null,
              onTap: () {
                appProvider.setLanguage("en");
                Navigator.pop(context);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: context.appSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.appCardBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(height: 1, color: context.appCardBorder);

  Widget _listTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: titleColor ?? context.appTextPrimary,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appSurface,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "الإعدادات",
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_right_3, color: AppColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _sectionHeader("الحساب"),
            _settingsCard(
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
                        color: Colors.orange.shade50,
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
            _sectionHeader("التفضيلات"),
            _settingsCard(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.moon,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    "الوضع الليلي",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: appProvider.darkMode,
                  activeColor: AppColors.primary,
                  onChanged: (val) async {
                    await appProvider.setDarkMode(val);
                  },
                ),
                _divider(),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.notification,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    "الإشعارات",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: appProvider.notificationsEnabled,
                  activeColor: AppColors.primary,
                  onChanged: appProvider.setNotificationsEnabled,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.language_square,
                  title: "اللغة",
                  subtitle: appProvider.language == "ar" ? "العربية" : "English",
                  trailing: const Icon(Iconsax.arrow_left_2, size: 18),
                  onTap: _showLanguageSheet,
                ),
              ],
            ),
            _sectionHeader("عن التطبيق"),
            _settingsCard(
              children: [
                _listTile(
                  icon: Iconsax.shield,
                  title: "سياسة الخصوصية",
                  onTap: () => _openUrl(_privacyUrl),
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.document,
                  title: "شروط الاستخدام",
                  onTap: () => _openUrl(_termsUrl),
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
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            _sectionHeader("الحساب"),
            _settingsCard(
              children: [
                _listTile(
                  icon: Iconsax.logout,
                  title: "تسجيل الخروج",
                  iconColor: Colors.red,
                  titleColor: Colors.red,
                  onTap: _logout,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.trash,
                  title: "حذف الحساب",
                  iconColor: Colors.red,
                  titleColor: Colors.red,
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
