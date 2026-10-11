import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/terms_acceptance_service.dart';
import '../../core/utils/theme_extensions.dart';

/// Full-screen Terms of Use. Sign-in cannot continue until the checkbox
/// is checked and Agree is tapped.
class TermsOfUseScreen extends StatefulWidget {
  final bool requireAcceptance;

  /// When false, the screen cannot be dismissed until the user accepts.
  final bool allowDecline;

  const TermsOfUseScreen({
    super.key,
    this.requireAcceptance = true,
    this.allowDecline = true,
  });

  @override
  State<TermsOfUseScreen> createState() => _TermsOfUseScreenState();
}

class _TermsOfUseScreenState extends State<TermsOfUseScreen> {
  static const zeroTolerance =
      'There is zero tolerance for objectionable content or abusive users. Any user who posts objectionable content or engages in abusive behavior will have their content removed and may be banned from the app.';

  bool _agreed = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() => _saving = true);
    await TermsAcceptanceService.markAccepted();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canLeave = !widget.requireAcceptance || widget.allowDecline;

    return PopScope(
      canPop: canLeave,
      child: Directionality(
        textDirection: LocalizationService.instance.textDirection,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: canLeave
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: cs.onSurface),
                    onPressed: () => Navigator.of(context).pop(
                      widget.requireAcceptance ? false : null,
                    ),
                  )
                : null,
            title: Text(
              tr('moderation.eula_title'),
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      tr('moderation.eula_subtitle'),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.primary, width: 1.4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Iconsax.shield_tick, color: cs.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tr('moderation.section_termination_title'),
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tr('moderation.eula_zero_tolerance'),
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (LocalizationService.instance.isArabic) ...[
                            const SizedBox(height: 10),
                            Text(
                              zeroTolerance,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                                height: 1.45,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _section(
                      context,
                      icon: Iconsax.user,
                      title: tr('moderation.section_conduct_title'),
                      body: tr('moderation.section_conduct_body'),
                    ),
                    _section(
                      context,
                      icon: Iconsax.warning_2,
                      title: tr('moderation.section_prohibited_title'),
                      body: tr('moderation.section_prohibited_body'),
                    ),
                    _section(
                      context,
                      icon: Iconsax.flag,
                      title: tr('moderation.section_reporting_title'),
                      body: tr('moderation.section_reporting_body'),
                    ),
                    _section(
                      context,
                      icon: Iconsax.user_remove,
                      title: tr('moderation.section_blocking_title'),
                      body: tr('moderation.section_blocking_body'),
                    ),
                    _section(
                      context,
                      icon: Iconsax.trash,
                      title: tr('moderation.section_termination_title'),
                      body: tr('moderation.section_termination_body'),
                    ),
                  ],
                ),
              ),
              _bottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.martIt.fieldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!widget.requireAcceptance) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(tr('common.close')),
            ),
          ),
        ),
      );
    }

    return Material(
      color: context.appSurface,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: _agreed,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _agreed = value ?? false),
                title: Text(
                  tr('moderation.eula_agree_checkbox'),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _agreed && !_saving ? _accept : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    disabledBackgroundColor: cs.primary.withValues(alpha: 0.35),
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text(
                          tr('moderation.eula_continue'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
