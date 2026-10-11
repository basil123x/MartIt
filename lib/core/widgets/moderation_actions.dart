import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/moderation_service.dart';
import '../utils/snackbar_helper.dart';
import 'report_sheet.dart';
import '../../features/auth/login.dart';

Future<String?> _signedInUser(BuildContext context) async {
  final existing = await AuthService.getCurrentUserId();
  if (existing != null && existing.isNotEmpty) return existing;
  if (!context.mounted) return null;
  showAppSnackbar(
    context,
    message: tr('common.login_required'),
    type: SnackType.error,
  );
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
  if (!context.mounted) return null;
  final uid = await AuthService.getCurrentUserId();
  if (uid == null || uid.isEmpty) return null;
  return uid;
}

/// Reason picker, local save, backend report, then a success confirmation.
Future<void> reportContent(
  BuildContext context, {
  required String targetType,
  String itemId = '',
  String commentId = '',
  String targetUid = '',
  String? title,
}) async {
  final uid = await _signedInUser(context);
  if (uid == null || !context.mounted) return;

  await showReportSheet(
    context: context,
    title: title ?? tr('moderation.report'),
    onSubmit: (reason, note) async {
      final result = await ModerationService.report(
        userId: uid,
        reason: reason,
        note: note,
        targetType: targetType,
        itemId: itemId,
        commentId: commentId,
        targetUid: targetUid,
      );
      if (!context.mounted) return;
      final sent = result['success'] == true;
      showAppSnackbar(
        context,
        message: sent ? tr('moderation.report_sent') : tr('common.error'),
        type: sent ? SnackType.success : SnackType.error,
      );
    },
  );
}

/// Asks for confirmation, stores the block locally and on the server,
/// then hides that user's content from the current session.
Future<bool> blockAbusiveUser(
  BuildContext context, {
  required String blockedUid,
  String name = '',
  Iterable<String> extraIds = const [],
}) async {
  final target = blockedUid.trim();
  if (target.isEmpty && name.trim().isEmpty) return false;
  final uid = await _signedInUser(context);
  if (uid == null || !context.mounted) return false;
  if (uid == target) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(tr('moderation.block_confirm_title')),
        content: Text(tr('moderation.block_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('moderation.block_confirm_action')),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return false;

  if (target.isNotEmpty) {
    await ModerationService.blockUser(
      blockerUid: uid,
      blockedUid: target,
    );
  }
  BlockedSellers.instance.block(
    [target, ...extraIds],
    name: name,
  );
  if (!context.mounted) return true;
  showAppSnackbar(context, message: tr('moderation.blocked'));
  return true;
}
