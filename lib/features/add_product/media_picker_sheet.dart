import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/services/localization_service.dart';

/// Shared polished bottom sheet for image/video source pickers (card-grid).
class MediaPickerSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<MediaPickerOption> options;

  /// When set, shows a back arrow to return to the previous chooser sheet.
  final VoidCallback? onBack;

  const MediaPickerSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    this.onBack,
  });

  static const Color _lightHandle = Color(0xFFE0DBF5);
  static const Color _darkHandle = Color(0xFF3A3A3E);
  static const Color _lightCard = Color(0xFFF5F3FF);
  static const Color _darkCard = Color(0xFF1C1C1F);
  static const Color _lightAccent = Color(0xFF5C33EA);
  static const Color _darkAccent = Color(0xFFC6FF3D);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final sheetBg = isDark ? const Color(0xFF0E0E10) : Colors.white;
    final handle = isDark ? _darkHandle : _lightHandle;
    final isAr = LocalizationService.instance.currentLanguage == 'ar';

    assert(
      options.isNotEmpty && options.length <= 4,
      'MediaPickerSheet expects 1–4 options',
    );

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: onBack != null
                      ? IconButton(
                          onPressed: onBack,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: cs.primary,
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Iconsax.close_circle,
                      color: cs.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionsGrid(isDark),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isAr ? 'إلغاء' : 'Cancel',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsGrid(bool isDark) {
    if (options.length == 1) {
      return Row(
        children: [
          const Spacer(),
          Expanded(
            flex: 2,
            child: _OptionCard(option: options[0], isDark: isDark),
          ),
          const Spacer(),
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 14));
      if (i + 1 < options.length) {
        rows.add(
          Row(
            children: [
              Expanded(
                child: _OptionCard(option: options[i], isDark: isDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _OptionCard(option: options[i + 1], isDark: isDark),
              ),
            ],
          ),
        );
      } else {
        rows.add(
          Row(
            children: [
              const Spacer(),
              Expanded(
                flex: 2,
                child: _OptionCard(option: options[i], isDark: isDark),
              ),
              const Spacer(),
            ],
          ),
        );
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class MediaPickerOption {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  const MediaPickerOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });
}

/// Backward-compatible aliases used by existing call sites.
typedef AddMediaOptionSheet = MediaPickerSheet;
typedef AddMediaOption = MediaPickerOption;

class _OptionCard extends StatefulWidget {
  final MediaPickerOption option;
  final bool isDark;

  const _OptionCard({
    required this.option,
    required this.isDark,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.option.accent ??
        (widget.isDark
            ? MediaPickerSheet._darkAccent
            : MediaPickerSheet._lightAccent);
    final cardBg = widget.isDark
        ? MediaPickerSheet._darkCard
        : MediaPickerSheet._lightCard;
    final cs = Theme.of(context).colorScheme;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.option.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 0.92,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.option.icon, color: accent, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.option.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.option.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
