import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

class AlbadaaUploadService {
  // ─── Config ──────────────────────────────────────────────────────────────
  static const String _uploadUrl =
      'https://albadaa-qatar.com/2026/works/stores/invoices/imgup/upload_item_media.php';

  static const String _cdnBase =
      'https://albadaa-qatar.com/2026/works/stores/invoices/imgup/itmapp';

  /// نفس الـ SECRET_KEY في ملف الـ PHP
  static const String _secretKey = 'AlBadaa_UPLOAD_SECRET_2026';

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
  List<String> uploadedUrls = [];

  for (int i = 0; i < filePaths.length; i++) {
    final formData = FormData();
    formData.fields.add(MapEntry('secret', _secretKey));
    formData.fields.add(MapEntry('item_id', itemId));
    formData.fields.add(MapEntry('file_index', (i + 1).toString()));

    final file = File(filePaths[i]);
    if (!file.existsSync()) continue;

    final ext = path.extension(filePaths[i]);
    formData.files.add(MapEntry(
      'files[]',
      await MultipartFile.fromFile(
        filePaths[i],
        filename: '${i + 1}$ext',
        contentType: _getDioContentType(filePaths[i]),
      ),
    ));

    try {
      final response = await _dio.post(
        _uploadUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (total <= 0 || onProgress == null) return;
          onProgress(i + 1, filePaths.length, sent / total);
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final uploaded = List<String>.from(response.data['uploaded'] ?? []);
        uploadedUrls.addAll(uploaded);
        print('✅ Uploaded file ${i + 1}/${filePaths.length}');
      }
    } catch (e) {
      print('❌ Error uploading file ${i + 1}: $e');
    }
  }

  return uploadedUrls;
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