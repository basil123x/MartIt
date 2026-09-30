import 'package:MartIt/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/localization_service.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String message;
  final String storeUrl;
  final String currentVersion;
  final String latestVersion;

  const ForceUpdateScreen({
    super.key,
    required this.message,
    required this.storeUrl,
    this.currentVersion = '',
    this.latestVersion = '',
  });

  Future<void> _launchStore() async {
    final url = storeUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = LocalizationService.instance.isArabic;
    final versionLine = currentVersion.isEmpty || latestVersion.isEmpty
        ? ''
        : isAr
            ? 'نسختك $currentVersion — المطلوب $latestVersion'
            : 'You have $currentVersion — required $latestVersion';

    return PopScope(
      canPop: false,
      child: Directionality(
        textDirection: LocalizationService.instance.textDirection,
        child: Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.refresh_circle,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isAr ? 'تحديث إجباري' : 'Update required',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  if (versionLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      versionLine,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: storeUrl.trim().isEmpty ? null : _launchStore,
                      child: Text(
                        isAr ? 'تحديث الآن' : 'Update now',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
