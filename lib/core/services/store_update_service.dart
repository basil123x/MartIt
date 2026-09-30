import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'api_config_service.dart';
import 'localization_service.dart';

class StoreUpdateRequirement {
  final String latestVersion;
  final String currentVersion;
  final String message;
  final String storeUrl;

  const StoreUpdateRequirement({
    required this.latestVersion,
    required this.currentVersion,
    required this.message,
    required this.storeUrl,
  });
}

/// Blocks the app when the installed build is behind the version published
/// in `app_config.json` (the same number on Play, App Store, and AppGallery).
class StoreUpdateService {
  StoreUpdateService._();
  static final StoreUpdateService instance = StoreUpdateService._();

  Future<StoreUpdateRequirement?> check() async {
    final config = ApiConfigService.instance;
    if (!config.forceUpdate) return null;

    final latest = config.latestVersion.trim();
    if (latest.isEmpty) return null;

    final info = await PackageInfo.fromPlatform();
    final current = info.version.trim();
    if (current.isEmpty || !_isOlder(current, latest)) return null;

    final isAr = LocalizationService.instance.isArabic;
    final fallback = isAr
        ? 'يتوفر إصدار جديد من MartIt. حدّث التطبيق من المتجر للمتابعة.'
        : 'A new MartIt version is available. Update from the store to continue.';

    return StoreUpdateRequirement(
      latestVersion: latest,
      currentVersion: current,
      message: config.updateMessageFor(isArabic: isAr).isNotEmpty
          ? config.updateMessageFor(isArabic: isAr)
          : fallback,
      storeUrl: _storeUrl(info),
    );
  }

  String _storeUrl(PackageInfo info) {
    final config = ApiConfigService.instance;
    if (Platform.isIOS) {
      return config.appStoreUrl;
    }

    final installer = (info.installerStore ?? '').toLowerCase();
    final fromHuawei = installer.contains('huawei') ||
        installer.contains('appmarket') ||
        installer.contains('appgallery');
    if (fromHuawei && config.huaweiStoreUrl.isNotEmpty) {
      return config.huaweiStoreUrl;
    }
    if (config.playStoreUrl.isNotEmpty) return config.playStoreUrl;
    return config.huaweiStoreUrl;
  }

  bool _isOlder(String current, String latest) {
    final currentParts = _parse(current);
    final latestParts = _parse(latest);
    final length = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;
    for (var i = 0; i < length; i++) {
      final a = i < currentParts.length ? currentParts[i] : 0;
      final b = i < latestParts.length ? latestParts[i] : 0;
      if (a != b) return a < b;
    }
    return false;
  }

  List<int> _parse(String version) {
    final withoutBuild = version.split('+').first.trim();
    return withoutBuild
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
