import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/localization_service.dart';
import '../../core/utils/theme_extensions.dart';
import '../../shared/providers/app_provider.dart';

/// Full language selection UI used at first-launch onboarding and from Settings.
class LanguageSelectionScreen extends StatefulWidget {
  /// When true (Settings), shows a back button and pops after confirm.
  final bool fromSettings;
  final ValueChanged<String>? onLanguageChanged;
  final VoidCallback? onConfirm;

  const LanguageSelectionScreen({
    super.key,
    this.fromSettings = true,
    this.onLanguageChanged,
    this.onConfirm,
  });

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = LocalizationService.instance.currentLanguage;
  }

  Future<void> _selectLanguage(String code) async {
    setState(() => _selectedLanguage = code);
    await LocalizationService.instance.changeLanguage(code);
    widget.onLanguageChanged?.call(code);
  }

  Future<void> _confirm() async {
    await LocalizationService.instance.changeLanguage(_selectedLanguage);
    if (!mounted) return;

    await context.read<AppProvider>().setLanguage(_selectedLanguage);

    if (widget.onConfirm != null) {
      widget.onConfirm!();
      return;
    }

    if (widget.fromSettings && mounted) {
      Navigator.of(context).pop(_selectedLanguage);
    }
  }

  Widget _buildFlagImage(String simCode, Color fallback) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        'https://flagcdn.com/w40/${simCode.toLowerCase()}.png',
        width: 36,
        height: 24,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.flag, size: 20, color: fallback),
      ),
    );
  }

  Widget _buildSelectionTile({
    required bool isSelected,
    required Widget leading,
    required String title,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selectedBg = context.isDarkMode
        ? cs.surface
        : cs.primaryContainer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  leading,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? cs.primary : cs.outline,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: context.appDivider,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final languages = [
      (code: 'en', sim: 'gb', title: 'English'),
      (
        code: 'ar',
        sim: 'sa',
        title: _selectedLanguage == 'ar' ? 'العربية' : 'Arabic',
      ),
    ];

    final isAr = _selectedLanguage == 'ar';
    final confirmLabel = widget.fromSettings
        ? (isAr ? 'تأكيد' : 'Confirm')
        : (isAr ? 'التالي' : 'Next');

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.appIconPillBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
                child: const Image(
                  image: AssetImage('assets/images/app-icon2.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            isAr ? 'اختر لغتك' : 'Choose your language',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isAr
                ? 'يمكنك تغيير اللغة لاحقاً من الإعدادات'
                : 'You can change the language later from settings',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 36),
          ...List.generate(languages.length, (index) {
            final lang = languages[index];
            final isSelected = _selectedLanguage == lang.code;
            return _buildSelectionTile(
              isSelected: isSelected,
              leading: _buildFlagImage(lang.sim, cs.onSurfaceVariant),
              title: lang.title,
              showDivider: index < languages.length - 1,
              onTap: () => _selectLanguage(lang.code),
            );
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _confirm,
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: widget.fromSettings
            ? AppBar(
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: cs.primary,
                    size: 20,
                  ),
                ),
              )
            : null,
        body: SafeArea(child: content),
      ),
    );
  }
}
