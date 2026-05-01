import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

class GesUploadService {
  // ─── Config ──────────────────────────────────────────────────────────────
  static const String _uploadUrl =
      'https://ges.qa/gesqatar/sys2026/attx/upload_item_media.php';

  static const String _cdnBase =
      'https://ges.qa/gesqatar/sys2026/attx/itmapp';

  /// نفس الـ SECRET_KEY في ملف الـ PHP
  static const String _secretKey = 'GES_UPLOAD_SECRET_2026';

  static final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 30)),
  );
  // ─────────────────────────────────────────────────────────────────────────

  /// ارفع قائمة ملفات لـ item معين
  /// بترجع قائمة الـ URLs المرفوعة
  static Future<List<String>> uploadMediaFiles({
    required List<String> filePaths,
    required String itemId,
    Function(int current, int total, double progress)? onProgress,
  }) async {
    try {
      final formData = FormData();

      // ضيف الـ auth والـ item_id
      formData.fields.add(MapEntry('secret', _secretKey));
      formData.fields.add(MapEntry('item_id', itemId));

      // ضيف كل الملفات
      for (int i = 0; i < filePaths.length; i++) {
        final file = File(filePaths[i]);
        if (!file.existsSync()) continue;

        final ext = path.extension(filePaths[i]);
        final fileName = '${i + 1}$ext'; // مجرد اسم مؤقت للـ multipart

        formData.files.add(
          MapEntry(
            'files[]',
            await MultipartFile.fromFile(
              filePaths[i],
              filename: fileName,
              contentType: _getDioContentType(filePaths[i]),
            ),
          ),
        );
      }

      int lastReported = -1;

      final response = await _dio.post(
        _uploadUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          final percent = (sent / total * 100).floor();
          if (percent != lastReported) {
            lastReported = percent;
            // نبلّغ بالـ progress الكلي مش per-file لأننا بنبعت كل حاجة مرة واحدة
            if (onProgress != null) {
              onProgress(filePaths.length, filePaths.length, sent / total);
            }
          }
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          final uploaded = List<String>.from(data['uploaded'] ?? []);
          print('✅ Uploaded ${uploaded.length} file(s) for item $itemId');

          if ((data['errors'] as List?)?.isNotEmpty == true) {
            print('⚠️ Partial errors: ${data['errors']}');
          }

          return uploaded;
        } else {
          print('❌ Server error: ${data['error']}');
          return [];
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Upload exception: $e');
      return [];
    }
  }

  /// ارفع صورة واحدة بس
  static Future<String?> uploadSingleFile({
    required String filePath,
    required String itemId,
    int index = 1,
    Function(double progress)? onProgress,
  }) async {
    final urls = await uploadMediaFiles(
      filePaths: [filePath],
      itemId: itemId,
      onProgress:
          onProgress != null
              ? (current, total, progress) => onProgress(progress)
              : null,
    );
    return urls.isNotEmpty ? urls.first : null;
  }

  /// ابني الـ URL يدوياً من غير ما ترفع (لو عارف الـ index والـ extension)
  static String buildUrl(String itemId, int index, String extension) {
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    return '$_cdnBase/$itemId/$index.$ext';
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static DioMediaType _getDioContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return DioMediaType('image', 'jpeg');
      case '.png':
        return DioMediaType('image', 'png');
      case '.gif':
        return DioMediaType('image', 'gif');
      case '.webp':
        return DioMediaType('image', 'webp');
      case '.mp4':
        return DioMediaType('video', 'mp4');
      case '.mov':
        return DioMediaType('video', 'quicktime');
      case '.avi':
        return DioMediaType('video', 'x-msvideo');
      default:
        return DioMediaType('application', 'octet-stream');
    }
  }
}