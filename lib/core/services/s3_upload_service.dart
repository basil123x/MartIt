import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:BML/core/constants/app_constants.dart';
import 'package:path/path.dart' as path;

Uint8List resizeAndEncodePng(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Failed to decode image');
  }
  final resized = img.copyResize(
    decoded,
    width: decoded.width > 1920 ? 1920 : decoded.width,
  );
  return Uint8List.fromList(img.encodePng(resized));
}

class S3UploadResult {
  final List<String> urls;
  final int? nextIdx;
  final int? clientId;

  const S3UploadResult({required this.urls, this.nextIdx, this.clientId});
}

class S3UploadService {
  static const String _defaultStoreId = AppConstants.albadaaStoreId;
  static const String _albadaaSyncKey = 'BML_Secret_2026';
  static const String _albadaaSyncUploadUrl =
      'https://bluemarinelife.com/sys2024/sync_upload.php';
  static const String _accessKey = 'AKIARVJRTCELH4VUZZ73';
  static const String _secretKey = '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';
  static const String _region = 'ap-south-1';
  static const String _baseUrl = 'https://martit.s3.ap-south-1.amazonaws.com';
  static const String _host = 'martit.s3.ap-south-1.amazonaws.com';

  static String _s3FolderForStore(String storeId) => 'store_$storeId';

  // GlobalFarm client bucket (only used when storeId == '2')
  static const String _clientBaseUrl =
      'https://globalfarmnursery.s3.ap-south-1.amazonaws.com';
  static const String _clientHost =
      'globalfarmnursery.s3.ap-south-1.amazonaws.com';
  static const String _clientStoreFolder = 'items';

  static final Dio _dio = Dio();

  static bool _isVideoExtension(String extension) {
    return extension == '.mp4' || extension == '.mov' || extension == '.avi';
  }

  static bool _isImageExtension(String extension) {
    return extension == '.jpg' ||
        extension == '.jpeg' ||
        extension == '.png' ||
        extension == '.gif' ||
        extension == '.webp';
  }

  static int parseApiInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  /// S3 object folder: store_4 uses [clientIdBadaa] from insertNewOne; other stores use [globeeItemId].
  static int s3FolderId({
    required String storeId,
    required int globeeItemId,
    required int clientIdBadaa,
  }) {
    if (storeId == AppConstants.albadaaStoreId) {
      return clientIdBadaa;
    }
    return globeeItemId;
  }

  static Future<S3UploadResult> uploadMediaFiles({
    required List<String> filePaths,
    int globeeItemId = 0,
    int clientIdBadaa = 0,
    String storeId = _defaultStoreId,
    Function(int current, int total, double progress)? onProgress,
  }) async {
    final uploadedUrls = <String>[];
    final allImages = <List<int>>[];
    final storeFolder = _s3FolderForStore(storeId);
    final folderId = s3FolderId(
      storeId: storeId,
      globeeItemId: globeeItemId,
      clientIdBadaa: clientIdBadaa,
    );

    if (folderId <= 0) {
      if (storeId == AppConstants.albadaaStoreId) {
        print('❌ client_id_badaa is required for store_4 S3 upload');
      } else {
        print('❌ clientId is required for S3 uploads (store_$storeId)');
      }
      return const S3UploadResult(urls: []);
    }

    print(
      '📤 S3UploadService.uploadMediaFiles storeId=$storeId folder=$storeFolder '
      's3FolderId=$folderId globeeItemId=$globeeItemId clientIdBadaa=$clientIdBadaa',
    );

    try {
      for (int i = 0; i < filePaths.length; i++) {
        final file = File(filePaths[i]);
        if (!file.existsSync()) continue;

        final extension = path.extension(filePaths[i]).toLowerCase();
        if (!_isImageExtension(extension) && !_isVideoExtension(extension)) {
          continue;
        }

        final String fileName;
        final List<int> payload;

        if (_isVideoExtension(extension)) {
          fileName = '${i + 1}$extension';
          payload = await file.readAsBytes();
        } else {
          fileName = '${i + 1}.png';
          try {
            final bytes = await file.readAsBytes();
            payload = await compute(resizeAndEncodePng, bytes);
          } catch (e) {
            print('Failed to convert image: ${filePaths[i]} — $e');
            continue;
          }
        }

        final objectKey = '$storeFolder/$folderId/$fileName';
        final uploadUrl = await _uploadBytes(
          payload,
          objectKey,
          storeId: storeId,
          clientId: folderId,
          fileNumber: i + 1,
          onProgress: (progress) {
            onProgress?.call(i + 1, filePaths.length, progress);
          },
        );
        if (uploadUrl != null) {
          uploadedUrls.add(uploadUrl);
          if (!_isVideoExtension(extension)) {
            allImages.add(payload);
          }
        }
      }

      if (uploadedUrls.isNotEmpty &&
          allImages.isNotEmpty &&
          storeId == AppConstants.albadaaStoreId &&
          clientIdBadaa > 0) {
        await _uploadToAlbadaaVps(
          allImageBytes: allImages,
          albadaaClientId: clientIdBadaa,
        );
      } else if (storeId == AppConstants.albadaaStoreId && clientIdBadaa <= 0) {
        print('⚠️ Skipping Albadaa VPS sync: client_id_badaa is missing');
      }

      return S3UploadResult(
        urls: uploadedUrls,
        nextIdx: folderId,
        clientId: folderId,
      );
    } catch (e) {
      print('Error uploading files: $e');
      return S3UploadResult(
        urls: uploadedUrls,
        nextIdx: folderId,
        clientId: folderId,
      );
    }
  }

  static Future<String?> _uploadBytes(
    List<int> bytes,
    String objectKey, {
    required String storeId,
    int? clientId,
    int fileNumber = 1,
    Function(double progress)? onProgress,
  }) async {
    try {
      final contentType = _getContentType(objectKey);
      final headers = _signedHeaders(
        method: 'PUT',
        objectKey: objectKey,
        contentType: contentType,
        payload: bytes,
      );

      final response = await _dio.put(
        '$_baseUrl/$objectKey',
        data: bytes,
        options: Options(headers: headers),
        onSendProgress: (sent, total) {
          final progress = total != 0 ? sent / total : 0.0;
          onProgress?.call(progress);
          print(
            'Uploading $objectKey: ${(progress * 100).toStringAsFixed(1)}%',
          );
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final url = '$_baseUrl/$objectKey';
        print('Uploaded: $url');

        if (storeId == '2' &&
            clientId != null &&
            clientId > 0 &&
            fileNumber == 1 &&
            !_isVideoExtension(path.extension(objectKey))) {
          await _copyToClientBucket(bytes: bytes, clientId: clientId);
        }

        return url;
      }

      print('Upload failed for $objectKey: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error uploading $objectKey: $e');
      return null;
    }
  }

  /// Mirror first image to Albadaa VPS (itmx/{client_id_badaa}.png on server).
  static Future<void> _uploadToAlbadaaVps({
    required List<List<int>> allImageBytes,
    required int albadaaClientId,
  }) async {
    if (allImageBytes.isEmpty || albadaaClientId <= 0) return;

    try {
      final decoded = img.decodeImage(Uint8List.fromList(allImageBytes[0]));
      if (decoded == null) {
        print('⚠️ Albadaa VPS: skipped thumbnail (decode failed)');
        return;
      }

      final resized = img.copyResize(decoded, width: 800);
      var payload = img.encodePng(resized);

      final uri = Uri.parse('$_albadaaSyncUploadUrl?id=$albadaaClientId');
      print(
        '📤 Albadaa VPS sync upload client_id_badaa=$albadaaClientId → itmx/$albadaaClientId.png',
      );

      Future<http.StreamedResponse> sendUpload(List<int> bytes) {
        final request = http.MultipartRequest('POST', uri);
        request.headers['X-Sync-Key'] = _albadaaSyncKey;
        request.fields['id'] = albadaaClientId.toString();
        request.files.add(
          http.MultipartFile.fromBytes(
            'upload',
            bytes,
            filename: '$albadaaClientId.png',
          ),
        );
        return request.send().timeout(const Duration(seconds: 30));
      }

      var response = await sendUpload(payload);
      var body = await response.stream.bytesToString();
      print('Albadaa VPS status: ${response.statusCode}');
      print('Albadaa VPS body: $body');

      if (response.statusCode == 413) {
        final smaller = img.copyResize(decoded, width: 400);
        payload = img.encodePng(smaller);
        response = await sendUpload(payload);
        body = await response.stream.bytesToString();
        print('Albadaa VPS retry status: ${response.statusCode}');
        print('Albadaa VPS retry body: $body');
      }

      if (response.statusCode == 200) {
        print('✅ Albadaa VPS thumbnail saved: itmx/$albadaaClientId.png');
      } else {
        print('❌ Albadaa VPS upload failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Albadaa VPS error: $e');
    }
  }

  static Future<void> _copyToClientBucket({
    required List<int> bytes,
    required int clientId,
  }) async {
    try {
      final clientObjectKey = '$_clientStoreFolder/$clientId.jpg';
      const contentType = 'image/jpeg';

      final headers = _signedHeaders(
        method: 'PUT',
        objectKey: clientObjectKey,
        contentType: contentType,
        payload: bytes,
        overrideHost: _clientHost,
      );

      final response = await _dio.put(
        '$_clientBaseUrl/$clientObjectKey',
        data: bytes,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Copied to client bucket: $_clientBaseUrl/$clientObjectKey');
      } else {
        print('❌ Copy failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error copying to client bucket: $e');
    }
  }

  static Future<bool> deleteFile(String remotePath) async {
    try {
      final objectKey = remotePath.startsWith('store_')
          ? remotePath
          : '${_s3FolderForStore(_defaultStoreId)}/$remotePath';
      final headers = _signedHeaders(
        method: 'DELETE',
        objectKey: objectKey,
        contentType: 'application/octet-stream',
        payload: const [],
      );

      final response = await _dio.delete(
        '$_baseUrl/$objectKey',
        options: Options(headers: headers),
      );

      return response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  static Map<String, String> _signedHeaders({
    required String method,
    required String objectKey,
    required String contentType,
    required List<int> payload,
    String? overrideHost,
  }) {
    final hostToUse = overrideHost ?? _host;
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);
    final payloadHash = sha256.convert(payload).toString();
    final canonicalUri = _canonicalUri(objectKey);

    final canonicalHeaders =
        'content-type:$contentType\n'
        'host:$hostToUse\n'
        'x-amz-content-sha256:$payloadHash\n'
        'x-amz-date:$amzDate\n';
    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest =
        '$method\n'
        '$canonicalUri\n'
        '\n'
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';

    final credentialScope = '$dateStamp/$_region/s3/aws4_request';
    final stringToSign =
        'AWS4-HMAC-SHA256\n'
        '$amzDate\n'
        '$credentialScope\n'
        '${sha256.convert(utf8.encode(canonicalRequest))}';

    final signingKey = _getSignatureKey(_secretKey, dateStamp, _region, 's3');
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();

    final authorization =
        'AWS4-HMAC-SHA256 '
        'Credential=$_accessKey/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    return {
      'Authorization': authorization,
      'Content-Type': contentType,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Host': hostToUse,
    };
  }

  static List<int> _getSignatureKey(
    String secretKey,
    String dateStamp,
    String region,
    String service,
  ) {
    final kDate = Hmac(
      sha256,
      utf8.encode('AWS4$secretKey'),
    ).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  static String _canonicalUri(String objectKey) {
    return '/${objectKey.split('/').map(Uri.encodeComponent).join('/')}';
  }

  static String _formatAmzDate(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}'
        'T'
        '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}'
        '${dateTime.second.toString().padLeft(2, '0')}'
        'Z';
  }

  static String _formatDateStamp(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}';
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
      case '.webp':
        return 'image/webp';
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
}
