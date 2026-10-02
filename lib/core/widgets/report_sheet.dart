import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/localization_service.dart';
import '../utils/snackbar_helper.dart';

const reportReasons = <String>[
  'moderation.reason_inappropriate',
  'moderation.reason_misleading',
  'moderation.reason_spam',
  'moderation.reason_harassment',
  'moderation.reason_other',
];

Future<void> showReportSheet({
  required BuildContext context,
  required String title,
  required Future<void> Function(String reason, String note) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return _ReportSheet(
        title: title,
        hostContext: context,
        onSubmit: onSubmit,
      );
    },
  );
}

class _ReportSheet extends StatefulWidget {
  final String title;
  final BuildContext hostContext;
  final Future<void> Function(String reason, String note) onSubmit;

  const _ReportSheet({
    required this.title,
    required this.hostContext,
    required this.onSubmit,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _selected;
  final TextEditingController _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final selected = _selected;
    if (selected == null || _submitting) return;
    final reason = tr(selected);
    final note = _noteController.text.trim();
    setState(() => _submitting = true);
    Navigator.of(context).pop();
    try {
      await widget.onSubmit(reason, note);
    } catch (_) {
      final host = widget.hostContext;
      if (host.mounted) {
        showAppSnackbar(
          host,
          message: tr('common.error'),
          type: SnackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...reportReasons.map((key) {
              return RadioListTile<String>(
                value: key,
                groupValue: _selected,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                title: Text(tr(key)),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _selected = value),
              );
            }),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: tr('moderation.note_hint'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selected == null || _submitting ? null : _submit,
              child: Text(tr('moderation.submit_report')),
            ),
          ],
        ),
      ),
    );
  }
}
