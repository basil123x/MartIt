import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 's3_upload_service.dart';

/// Keeps product photo/video uploads running after the add-product screen closes.
class BackgroundMediaUploadService extends ChangeNotifier {
  BackgroundMediaUploadService._();

  static final BackgroundMediaUploadService instance =
      BackgroundMediaUploadService._();

  final Map<String, _UploadJob> _jobs = {};
  final Map<String, Future<void>> _tails = {};

  bool isUploading(String? itemId) {
    if (itemId == null || itemId.isEmpty) return false;
    return _jobs[itemId]?.isActive ?? false;
  }

  double progressOf(String? itemId) {
    if (itemId == null || itemId.isEmpty) return 0;
    return _jobs[itemId]?.overallProgress ?? 0;
  }

  List<String> previewPaths(String? itemId) {
    if (itemId == null || itemId.isEmpty) return const [];
    return List<String>.from(_jobs[itemId]?.previewPaths ?? const []);
  }

  String savedMediaOf(String? itemId) {
    if (itemId == null || itemId.isEmpty) return '';
    return _jobs[itemId]?.savedMedia ?? '';
  }

  int uploadedCountOf(String? itemId) {
    if (itemId == null || itemId.isEmpty) return 0;
    return _jobs[itemId]?.uploadedCount ?? 0;
  }

  Map<String, double> progressByPath(String? itemId) {
    if (itemId == null || itemId.isEmpty) return const {};
    return Map<String, double>.from(_jobs[itemId]?.progress ?? const {});
  }

  List<String> activeItemIds() {
    return _jobs.entries
        .where((entry) => entry.value.isActive)
        .map((entry) => entry.key)
        .toList();
  }

  Map<String, dynamic>? profileSnapshot(String itemId) {
    final snapshot = _jobs[itemId]?.snapshot;
    if (snapshot == null) return null;
    return Map<String, dynamic>.from(snapshot);
  }

  void rememberSnapshot(String itemId, Map<String, dynamic> snapshot) {
    final job = _jobs[itemId];
    if (job == null || !job.isActive) return;
    job.snapshot = Map<String, dynamic>.from(snapshot);
    notifyListeners();
  }

  void enqueue({
    required String itemId,
    required List<String> paths,
    int startIndex = 0,
    String savedMedia = '',
  }) {
    if (itemId.isEmpty || paths.isEmpty) return;
    final job = _jobs.putIfAbsent(itemId, () => _UploadJob(itemId));
    if (!job.started) {
      job.uploadedCount = startIndex;
      job.savedMedia = savedMedia;
      job.started = true;
    } else if (job.savedMedia.isEmpty && savedMedia.isNotEmpty) {
      job.savedMedia = savedMedia;
    }

    for (final path in paths) {
      if (path.isEmpty || job.knownPaths.contains(path)) continue;
      job.knownPaths.add(path);
      job.previewPaths.add(path);
      job.queue.add(path);
      job.progress[path] = 0;
    }
    notifyListeners();
    unawaited(_pump(job));
  }

  void cancelPath(String itemId, String path) {
    final job = _jobs[itemId];
    if (job == null) return;
    job.queue.remove(path);
    job.progress.remove(path);
    job.previewPaths.remove(path);
    job.skipped.add(path);
    notifyListeners();
  }

  void syncSavedMedia(
    String itemId, {
    required int uploadedCount,
    required String savedMedia,
  }) {
    final job = _jobs[itemId];
    if (job == null) return;
    job.uploadedCount = uploadedCount;
    job.savedMedia = savedMedia;
  }

  Future<T> runExclusive<T>(String itemId, Future<T> Function() action) {
    final result = Completer<T>();
    final previous = _tails[itemId] ?? Future<void>.value();
    final gate = Completer<void>();
    _tails[itemId] = gate.future;
    previous.whenComplete(() async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        if (!gate.isCompleted) gate.complete();
      }
    });
    return result.future;
  }

  Future<void> _pump(_UploadJob job) async {
    if (job.pumping) return;
    job.pumping = true;
    try {
      while (job.queue.isNotEmpty) {
        final path = job.queue.removeAt(0);
        if (job.skipped.contains(path)) {
          job.progress.remove(path);
          continue;
        }

        job.progress[path] = 0;
        notifyListeners();

        try {
          final uploadedUrls = await S3UploadService.uploadMediaFiles(
            filePaths: [path],
            itemId: job.itemId,
            startIndex: job.uploadedCount,
            onFileProgress: (_, filePath, progress) {
              if (job.skipped.contains(filePath)) return;
              job.progress[filePath] = progress.clamp(0.0, 1.0);
              notifyListeners();
            },
          );

          if (job.skipped.contains(path) || uploadedUrls.isEmpty) {
            continue;
          }

          final names = uploadedUrls.map((url) => url.split('/').last).toList();
          await runExclusive(job.itemId, () async {
            if (job.skipped.contains(path)) return;
            job.uploadedCount += names.length;
            final chunk = names.join(', ');
            job.savedMedia = job.savedMedia.isEmpty
                ? chunk
                : '${job.savedMedia}, $chunk';
            await ApiService.updateItemMedia(
              itemId: job.itemId,
              media: job.savedMedia,
            );
          });
        } catch (error) {
          debugPrint('Background media upload error: $error');
        } finally {
          job.progress.remove(path);
          notifyListeners();
        }
      }
    } finally {
      job.pumping = false;
    }

    if (job.queue.isNotEmpty) {
      await _pump(job);
      return;
    }
    if (!job.isActive) {
      _jobs.remove(job.itemId);
      notifyListeners();
    }
  }
}

class _UploadJob {
  _UploadJob(this.itemId);

  final String itemId;
  final List<String> queue = [];
  final List<String> previewPaths = [];
  final Set<String> knownPaths = {};
  final Set<String> skipped = {};
  final Map<String, double> progress = {};
  int uploadedCount = 0;
  String savedMedia = '';
  bool pumping = false;
  bool started = false;
  Map<String, dynamic>? snapshot;

  bool get isActive => queue.isNotEmpty || progress.isNotEmpty || pumping;

  double get overallProgress {
    if (previewPaths.isEmpty) return 0;
    var sum = 0.0;
    for (final path in previewPaths) {
      if (skipped.contains(path)) continue;
      sum += progress[path] ?? (knownPaths.contains(path) ? 1 : 0);
    }
    final total = previewPaths.where((path) => !skipped.contains(path)).length;
    if (total == 0) return 0;
    return (sum / total).clamp(0.0, 1.0);
  }
}
