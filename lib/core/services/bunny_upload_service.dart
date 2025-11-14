import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

class BunnyUploadService {
  static const String _storageZoneName = 'globee-trading';
  static const String _accessKey = '18808acb-f5f1-473e-bd84cf669411-20c0-499c';
  static const String _cdnUrl = 'https://globee.b-cdn.net';
  static const String _storageUrl =
      'https://storage.bunnycdn.com/$_storageZoneName';

  static final Dio _dio = Dio();

  static Future<List<String>> uploadMediaFiles({
    required List<String> filePaths,
    required String itemId,
  }) async {
    List<String> uploadedUrls = [];

    try {
      for (int i = 0; i < filePaths.length; i++) {
        final file = File(filePaths[i]);
        if (!file.existsSync()) continue;

        final extension = path.extension(filePaths[i]);
        final fileName = '${i + 1}$extension';
        final remotePath = '$itemId/$fileName';

        final uploadUrl = await _uploadFile(file, remotePath);
        if (uploadUrl != null) {
          uploadedUrls.add(uploadUrl);
        }
      }

      return uploadedUrls;
    } catch (e) {
      print('Error uploading files: $e');
      return [];
    }
  }

  static Future<String?> _uploadFile(File file, String remotePath) async {
    try {
      final bytes = await file.readAsBytes();

      final response = await _dio.put(
        '$_storageUrl/$remotePath',
        data: bytes,
        options: Options(
          headers: {
            'AccessKey': _accessKey,
            'Content-Type': _getContentType(remotePath),
          },
        ),
        onSendProgress: (sent, total) {
          final progress = total != 0 ? sent / total : 0.0;
          print(
            'Uploading $remotePath: ${(progress * 100).toStringAsFixed(1)}%',
          );
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final url = '$_cdnUrl/$remotePath';
        print('✅ Uploaded: $url');
        return url;
      } else {
        print('❌ Upload failed for $remotePath: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error uploading $remotePath: $e');
      return null;
    }
  }

  static String _getContentType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<bool> deleteFile(String remotePath) async {
    try {
      final response = await _dio.delete(
        '$_storageUrl/$remotePath',
        options: Options(headers: {'AccessKey': _accessKey}),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }
}
