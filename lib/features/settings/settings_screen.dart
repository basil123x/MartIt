import "dart:convert";
import "dart:io";

import "package:awesome_dialog/awesome_dialog.dart";
import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:iconsax/iconsax.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:provider/provider.dart";
import "package:sign_in_with_apple/sign_in_with_apple.dart";
import "package:url_launcher/url_launcher.dart";

import "../../core/constants/app_colors.dart";
import "../../core/constants/app_theme.dart";
import "../../core/models/item_model.dart";
import "../../core/services/auth_service.dart";
import "../../core/utils/snackbar_helper.dart";
import "../../core/utils/theme_extensions.dart";
import "../../shared/providers/app_provider.dart";
import "../auth/login.dart";
import "../auth/terms_of_use_screen.dart";
import "../onboarding/language_selection_screen.dart";
import "../profile/edit_profile_screen.dart";
import "policy_screen.dart";
import '../../core/services/api_config_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/s3_upload_service.dart';
import 'blocked_users_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserProfileModel? profile;

  const SettingsScreen({super.key, this.profile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _storage = FlutterSecureStorage();

  String _appVersion = "";
  UserProfileModel? _profile;

  static String get _privacyUrl =>
      ApiConfigService.instance.endpoint('PrivacyPolicy.php');

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
      title: tr("settings.logout_title"),
      desc: tr("settings.logout_body"),
      btnCancelText: tr("common.cancel"),
      btnOkText: tr("settings.logout"),
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
      title: tr("moderation.delete_account_title"),
      desc: tr("moderation.delete_account_body"),
      btnCancelText: tr("common.cancel"),
      btnOkText: tr("moderation.delete_forever"),
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final uid = await AuthService.getCurrentUID();
        if (uid == null || uid.isEmpty) {
          _showSnack("تعذر تحديد المستخدم", isError: true);
          return;
        }

        final loginType = (await _storage.read(key: "login_type") ?? "")
            .toLowerCase();
        final fields = <String, String>{
          "action": "delete_account_permit",
          "uid": uid,
        };

        if (loginType == "apple") {
          try {
            final credential = await SignInWithApple.getAppleIDCredential(
              scopes: const [],
            );
            final appleUserId = credential.userIdentifier ?? "";
            if (credential.authorizationCode.isEmpty || appleUserId.isEmpty) {
              _showSnack(tr("moderation.apple_revoke_retry"), isError: true);
              return;
            }
            fields["apple_authorization_code"] = credential.authorizationCode;
            fields["apple_user_id"] = appleUserId;
          } on SignInWithAppleAuthorizationException catch (e) {
            if (e.code == AuthorizationErrorCode.canceled) {
              _showSnack(tr("moderation.apple_delete_cancelled"), isError: true);
            } else {
              _showSnack(tr("moderation.apple_revoke_retry"), isError: true);
            }
            return;
          } catch (_) {
            _showSnack(tr("moderation.apple_revoke_retry"), isError: true);
            return;
          }
        }

        try {
          final response = await Dio().post(
            "${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
            data: FormData.fromMap(fields),
            options: Options(
              validateStatus: (status) => status != null && status < 500,
              responseType: ResponseType.plain,
            ),
          );
          if (kDebugMode) {
            debugPrint(
              "delete_account raw: ${response.statusCode} ${response.data}",
            );
          }
          final data = _decodeDeleteBody(response.data);
          await _handleDeleteAccountResponse(data);
        } on DioException catch (e) {
          if (kDebugMode) {
            debugPrint(
              "delete_account raw: ${e.response?.statusCode} ${e.response?.data} $e",
            );
          }
          final data = _decodeDeleteBody(e.response?.data);
          if (data is Map && _deleteSucceeded(data)) {
            await _finishDeletedAccount(data);
            return;
          }
          final errorCode = data is Map ? data["error"]?.toString() : null;
          if (errorCode == "apple_revoke_failed" ||
              errorCode == "apple_identity_mismatch") {
            _showSnack(tr("moderation.apple_revoke_retry"), isError: true);
          } else {
            _showSnack("حدث خطأ أثناء حذف الحساب", isError: true);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint("delete_account raw: $e");
          }
          _showSnack("حدث خطأ أثناء حذف الحساب", isError: true);
        }
      },
    ).show();
  }

  dynamic _decodeDeleteBody(dynamic raw) {
    if (raw is Map) return raw;
    if (raw is! String) return raw;
    final text = raw.trim();
    try {
      return jsonDecode(text);
    } catch (_) {
      final start = text.indexOf("{");
      final end = text.lastIndexOf("}");
      if (start >= 0 && end > start) {
        try {
          return jsonDecode(text.substring(start, end + 1));
        } catch (_) {}
      }
    }
    return raw;
  }

  bool _deleteSucceeded(Map data) {
    final success = data["success"];
    return success == true || success == 1 || success == "true";
  }

  Future<void> _handleDeleteAccountResponse(dynamic data) async {
    final errorCode = data is Map ? data["error"]?.toString() : null;
    if (data is Map && _deleteSucceeded(data)) {
      await _finishDeletedAccount(data);
      return;
    }
    if (errorCode == "apple_revoke_failed" ||
        errorCode == "apple_identity_mismatch") {
      _showSnack(tr("moderation.apple_revoke_retry"), isError: true);
      return;
    }
    _showSnack(errorCode ?? "فشل في حذف الحساب", isError: true);
  }

  Future<void> _finishDeletedAccount(Map data) async {
    final media = data["media"];
    if (media is List) {
      for (final file in media) {
        try {
          await S3UploadService.deleteFile(file.toString());
        } catch (e) {
          if (kDebugMode) {
            debugPrint("delete_account media: $e");
          }
        }
      }
    }
    try {
      await AuthService.logout();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("delete_account logout: $e");
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
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
        alignment: AlignmentDirectional.centerStart,
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
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            tr("settings.title"),
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
              child: _sectionHeader(tr("settings.account")),
            ),
            _settingsSection(
              children: [
                _listTile(
                  icon: Iconsax.edit,
                  title: tr("settings.edit_profile"),
                  onTap: _profile != null ? _openEditProfile : null,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.user_remove,
                  title: tr("moderation.blocked_users"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BlockedUsersScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionHeader(tr("settings.preferences")),
            ),
            _settingsSection(
              children: [
                _switchTile(
                  icon: Iconsax.moon,
                  title: tr("settings.dark_mode"),
                  value: appProvider.darkMode,
                  onChanged: (val) async {
                    await appProvider.setDarkMode(val);
                  },
                ),
                _divider(),
                _switchTile(
                  icon: Iconsax.notification,
                  title: tr("settings.notifications"),
                  value: appProvider.notificationsEnabled,
                  onChanged: appProvider.setNotificationsEnabled,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.language_square,
                  title: tr("settings.language"),
                  subtitle: appProvider.language == "ar"
                      ? "العربية"
                      : "English",
                  trailing: Icon(
                    LocalizationService.instance.isArabic
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    size: 22,
                    color: context.appTextSecondary,
                  ),
                  onTap: _openLanguageSelection,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionHeader(tr("settings.about")),
            ),
            _settingsSection(
              children: [
                _listTile(
                  icon: Iconsax.shield,
                  title: tr("settings.privacy"),
                  onTap: () => _openPolicyPage(
                    title: tr("settings.privacy"),
                    url: _privacyUrl,
                  ),
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.document,
                  title: tr("settings.terms"),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsOfUseScreen(
                        requireAcceptance: false,
                      ),
                    ),
                  ),
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.sms,
                  title: tr("moderation.contact_us"),
                  subtitle: "support@mart-it.store",
                  onTap: () => launchUrl(Uri.parse("mailto:support@mart-it.store")),
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
                  title: tr("settings.version"),
                  trailing: Text(
                    _appVersion.isNotEmpty ? _appVersion : "1.2.6",
                    style: TextStyle(color: context.appTextSecondary),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionHeader(tr("settings.account")),
            ),
            _settingsSection(
              children: [
                _listTile(
                  icon: Iconsax.logout,
                  title: tr("settings.logout"),
                  iconColor: AppColors.error,
                  iconBg: martIt.dangerBg,
                  titleColor: AppColors.error,
                  onTap: _logout,
                ),
                _divider(),
                _listTile(
                  icon: Iconsax.trash,
                  title: tr("moderation.delete_account"),
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
