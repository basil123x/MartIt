import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/terms_of_use_screen.dart';
import 'auth_service.dart';
import 'moderation_service.dart';

/// Records that this device accepted the Terms of Use, and mirrors that
/// acceptance onto the signed-in account when a user id exists.
class TermsAcceptanceService {
  static const acceptedKey = 'eula_accepted_v1';
  static const acceptedAtKey = 'eula_accepted_at_v1';
  static const acceptedUidKey = 'eula_accepted_uid_v1';

  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(acceptedKey) ?? false;
  }

  /// True when this signed-in account has not accepted yet.
  static Future<bool> needsAcceptanceFor(String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(acceptedKey) ?? false)) return true;
    if (uid == null || uid.isEmpty) return false;
    final saved = prefs.getString(acceptedUidKey);
    if (saved == null || saved.isEmpty) return false;
    return saved != uid;
  }

  static Future<void> markAccepted({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(acceptedKey, true);
    await prefs.setString(acceptedAtKey, DateTime.now().toIso8601String());
    if (uid != null && uid.isNotEmpty) {
      await prefs.setString(acceptedUidKey, uid);
    }
  }

  /// Clears acceptance so the next sign-in must agree again.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(acceptedKey);
    await prefs.remove(acceptedAtKey);
    await prefs.remove(acceptedUidKey);
  }

  /// Saves acceptance locally and notifies the backend for [uid].
  static Future<void> syncWithAccount(String? uid) async {
    await markAccepted(uid: uid);
    if (uid == null || uid.isEmpty) return;
    await ModerationService.acceptTerms(uid);
  }

  static Future<void> syncCurrentAccount() async {
    final uid = await AuthService.getCurrentUserId();
    await syncWithAccount(uid);
  }

  /// Opens the Terms screen when acceptance is still required.
  /// Returns true only after the user checks the box and continues.
  static Future<bool> ensureAccepted(
    BuildContext context, {
    bool allowDecline = true,
  }) async {
    if (await hasAccepted()) return true;
    if (!context.mounted) return false;
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TermsOfUseScreen(
          requireAcceptance: true,
          allowDecline: allowDecline,
        ),
      ),
    );
    return accepted == true;
  }
}
