import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:terminate_restart/terminate_restart.dart';

/// Downloads a Shorebird patch and restarts twice so the new patch is the one
/// actually running. Also used while the app is open and on a cold start.
class ShorebirdUpdateService {
  ShorebirdUpdateService._();
  static final ShorebirdUpdateService instance = ShorebirdUpdateService._();

  final ShorebirdUpdater _updater = ShorebirdUpdater();
  bool _busy = false;

  static const _savedPatchKey = 'shorebird_saved_patch';
  static const _stageKey = 'shorebird_stage';
  static const _countKey = 'shorebird_restart_count';
  static const _countAtKey = 'shorebird_restart_at';

  /// Returns true when Android is about to terminate for a restart.
  Future<bool> sync() async {
    if (_busy) return false;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await _updater.readCurrentPatch();
      final currentNumber = current?.number ?? 0;
      final stage = prefs.getInt(_stageKey) ?? 0;

      // First restart downloaded the patch. Second restart makes sure the
      // process is running that patch.
      if (stage == 1) {
        await prefs.setInt(_savedPatchKey, currentNumber);
        await prefs.setInt(_stageKey, 2);
        return _restart();
      }

      if (stage == 2) {
        await prefs.setInt(_stageKey, 0);
        await prefs.setInt(_countKey, 0);
      }

      final status = await _updater.checkForUpdate();
      if (status != UpdateStatus.outdated &&
          status != UpdateStatus.restartRequired) {
        return false;
      }

      if (status == UpdateStatus.outdated) {
        await _updater.update();
      }

      if (!_canRestart(prefs)) return false;

      await prefs.setInt(_savedPatchKey, currentNumber);
      await prefs.setInt(_stageKey, 1);
      await _bumpCount(prefs);
      return _restart();
    } on UpdateException catch (error) {
      debugPrint('Shorebird update failed: $error');
      return false;
    } finally {
      _busy = false;
    }
  }

  bool _canRestart(SharedPreferences prefs) {
    final count = prefs.getInt(_countKey) ?? 0;
    final at = prefs.getInt(_countAtKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - at;
    if (elapsed > const Duration(minutes: 10).inMilliseconds) {
      return true;
    }
    return count < 2;
  }

  Future<void> _bumpCount(SharedPreferences prefs) async {
    final at = prefs.getInt(_countAtKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - at;
    var count = prefs.getInt(_countKey) ?? 0;
    if (elapsed > const Duration(minutes: 10).inMilliseconds) {
      count = 0;
    }
    await prefs.setInt(_countKey, count + 1);
    await prefs.setInt(_countAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> _restart() async {
    if (Platform.isIOS) {
      Restart.restartApp(
        notificationTitle: 'تحديث',
        notificationBody: 'جاري تطبيق آخر تحديث',
      );
      return false;
    }

    await TerminateRestart.instance.restartApp(
      options: const TerminateRestartOptions(terminate: true),
    );
    return true;
  }
}
