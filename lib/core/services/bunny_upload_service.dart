import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';

class S3UploadService {
  static const String _accessKey  = 'AKIARVJRTCELH4VUZZ73';
  static const String _secretKey  = '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';
  static const String _bucketName = 'globalfarmnursery';
  static const String _region     = 'ap-south-1';
  static const String _baseUrl    =
      'https://$_bucketName.s3.$_region.amazonaws.com';

  static final Dio _dio = Dio();

  // ─── نفس الـ signature بتاعة BunnyUploadService ───
  static Future<List<String>> uploadMediaFiles({
    required List<String> filePaths,
    required String itemId,
    Function(int current, int total, double progress)? onProgress,
  }) async {
    final List<String> uploadedUrls = [];

    for (int i = 0; i < filePaths.length; i++) {
      final file = File(filePaths[i]);
      if (!file.existsSync()) continue;

      final ext      = path.extension(filePaths[i]);
      final fileName = '${i + 1}$ext';
      final s3Key    = '$itemId/$fileName';

      final url = await _uploadFile(
        file,
        s3Key,
        onProgress: (progress) =>
            onProgress?.call(i + 1, filePaths.length, progress),
      );

      if (url != null) uploadedUrls.add(url);
    }

    return uploadedUrls;
  }

  // ─── الرفع الفعلي ───
  static Future<String?> _uploadFile(
    File file,
    String s3Key, {
    Function(double progress)? onProgress,
  }) async {
    try {
      final bytes       = await file.readAsBytes();
      final contentType = _getContentType(s3Key);
      final now         = DateTime.now().toUtc();
      final dateStamp   = _dateStamp(now);
      final amzDateTime = _amzDateTime(now);
      final payloadHash = sha256.convert(bytes).toString();

      final headers = <String, String>{
        'content-type'        : contentType,
        'host'                : '$_bucketName.s3.$_region.amazonaws.com',
        'x-amz-content-sha256': payloadHash,
        'x-amz-date'          : amzDateTime,
      };

      final authorization = _sign(
        method      : 'PUT',
        s3Key       : s3Key,
        headers     : headers,
        payloadHash : payloadHash,
        dateStamp   : dateStamp,
        amzDateTime : amzDateTime,
      );

      final response = await _dio.put(
        '$_baseUrl/$s3Key',
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            ...headers,
            'Authorization' : authorization,
            'Content-Length': bytes.length,
          },
          requestEncoder: (_, __) => bytes,
        ),
        onSendProgress: (sent, total) {
          final p = total > 0 ? sent / total : 0.0;
          onProgress?.call(p);
          print('⬆️  $s3Key — ${(p * 100).toStringAsFixed(1)}%');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final url = '$_baseUrl/$s3Key';
        print('✅ Uploaded: $url');
        return url;
      }

      print('❌ Failed ${response.statusCode}: ${response.data}');
      return null;
    } catch (e) {
      print('❌ Error uploading $s3Key: $e');
      return null;
    }
  }

  // ─── AWS Signature V4 ───
  static String _sign({
    required String method,
    required String s3Key,
    required Map<String, String> headers,
    required String payloadHash,
    required String dateStamp,
    required String amzDateTime,
  }) {
    final sortedKeys       = headers.keys.toList()..sort();
    final canonicalHeaders = sortedKeys.map((k) => '$k:${headers[k]}').join('\n') + '\n';
    final signedHeaders    = sortedKeys.join(';');

    final canonicalRequest = [
      method,
      '/$s3Key',
      '',
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final credentialScope = '$dateStamp/$_region/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDateTime,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey  = _signingKey(dateStamp);
    final signature   = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    return 'AWS4-HMAC-SHA256 '
        'Credential=$_accessKey/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';
  }

  static List<int> _signingKey(String dateStamp) {
    List<int> hmac(List<int> key, String msg) =>
        Hmac(sha256, key).convert(utf8.encode(msg)).bytes;

    return hmac(
      hmac(
        hmac(
          hmac(utf8.encode('AWS4$_secretKey'), dateStamp),
          _region,
        ),
        's3',
      ),
      'aws4_request',
    );
  }

  // ─── حذف ملف ───
  static Future<bool> deleteFile(String s3Key) async {
    try {
      const emptyHash =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      final now         = DateTime.now().toUtc();
      final dateStamp   = _dateStamp(now);
      final amzDateTime = _amzDateTime(now);

      final headers = <String, String>{
        'host'                : '$_bucketName.s3.$_region.amazonaws.com',
        'x-amz-content-sha256': emptyHash,
        'x-amz-date'          : amzDateTime,
      };

      final authorization = _sign(
        method      : 'DELETE',
        s3Key       : s3Key,
        headers     : headers,
        payloadHash : emptyHash,
        dateStamp   : dateStamp,
        amzDateTime : amzDateTime,
      );

      final response = await _dio.delete(
        '$_baseUrl/$s3Key',
        options: Options(
          headers: {...headers, 'Authorization': authorization},
        ),
      );

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Error deleting $s3Key: $e');
      return false;
    }
  }

  // ─── Helpers ───
  static String _dateStamp(DateTime dt) =>
      '${dt.year}${_p(dt.month)}${_p(dt.day)}';

  static String _amzDateTime(DateTime dt) =>
      '${_dateStamp(dt)}T${_p(dt.hour)}${_p(dt.minute)}${_p(dt.second)}Z';

  static String _p(int n) => n.toString().padLeft(2, '0');

  static String _getContentType(String filePath) {
    switch (path.extension(filePath).toLowerCase()) {
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.png':  return 'image/png';
      case '.gif':  return 'image/gif';
      case '.mp4':  return 'video/mp4';
      case '.mov':  return 'video/quicktime';
      case '.avi':  return 'video/x-msvideo';
      default:      return 'application/octet-stream';
    }
  }
}