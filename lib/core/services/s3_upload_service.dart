import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:image/image.dart" as img;
import "package:path/path.dart" as path;

Uint8List convertImageToPng(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception("Failed to decode image");
  }
  return Uint8List.fromList(img.encodePng(decoded));
}

class S3UploadResult {
  final List<String> urls;
  final int? nextIdx;

  /// Client DB items.id used for items/{clientId}.png on globalfarmnursery bucket.
  final int? clientId;

  const S3UploadResult({
    required this.urls,
    this.nextIdx,
    this.clientId,
  });
}

class S3UploadService {
  static const String _apiBaseUrl = "https://www.globee-trading.com/app2026";
  static const String _globalFarmStoreId = "2";
  static const String _accessKey = "AKIARVJRTCELH4VUZZ73";
  static const String _secretKey = "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";
  static const String _region = "ap-south-1";
  static const String _bucket = "martit";
  static const String _baseUrl = "https://martit.s3.ap-south-1.amazonaws.com";
  static const String _storeFolder = "store_2";
  static const String _host = "martit.s3.ap-south-1.amazonaws.com";

  // Client S3 Config
  static const String _clientBucket = "globalfarmnursery";
  static const String _clientBaseUrl = "https://globalfarmnursery.s3.ap-south-1.amazonaws.com";
  static const String _clientHost = "globalfarmnursery.s3.ap-south-1.amazonaws.com";
  static const String _clientStoreFolder = "items";

  static final Dio _dio = Dio();

  static bool _isVideoExtension(String extension) {
    return extension == ".mp4" || extension == ".mov" || extension == ".avi";
  }

  static bool _isImageExtension(String extension) {
    return extension == ".jpg" ||
        extension == ".jpeg" ||
        extension == ".png" ||
        extension == ".gif" ||
        extension == ".webp";
  }

  static Future<int> fetchNextIdx({String storeId = _globalFarmStoreId}) async {
    try {
      final response = await _dio.get(
        "$_apiBaseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
        queryParameters: {"action": "get_last_idx", "store_id": storeId},
      );
      final dynamic body = response.data;
      if (body is Map) {
        final dynamic lastIdxRaw = body["last_idx"];
        final int lastIdx = lastIdxRaw is num
            ? lastIdxRaw.toInt()
            : int.tryParse(lastIdxRaw?.toString() ?? "") ?? 0;
        return lastIdx + 1;
      }
    } catch (e) {
      print("Error fetching last idx: $e");
    }
    return 1;
  }

  static Future<S3UploadResult> uploadMediaFiles({
    required List<String> filePaths,
    String? folderName,
    String? itemId,
    int clientItemId = 0,
    bool useSequentialIdx = true,
    String storeId = _globalFarmStoreId,
    Function(int current, int total, double progress)? onProgress,
  }) async {
    final uploadedUrls = <String>[];
    int? allocatedIdx;
    final int? clientIdForThumb = clientItemId > 0 ? clientItemId : null;

    try {
final String uploadFolder;
if (useSequentialIdx) {
  if (clientItemId > 0) {
    // ✅ استخدم clientId مباشرة
    allocatedIdx = clientItemId;
    uploadFolder = clientItemId.toString();
    print("📁 S3 upload folder (client id): $uploadFolder");
  } else {
    allocatedIdx = await fetchNextIdx(storeId: storeId);
    uploadFolder = allocatedIdx.toString();
    print("📁 S3 upload folder (next idx): $uploadFolder");
  }
} else {
  final String? resolvedFolder = folderName ?? itemId;
  if (resolvedFolder == null || resolvedFolder.isEmpty) {
    throw Exception("folderName is required when useSequentialIdx is false");
  }
  uploadFolder = resolvedFolder;
}

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
          fileName = "${i + 1}$extension";
          payload = await file.readAsBytes();
        } else {
          fileName = "${i + 1}.png";
          try {
            final bytes = await file.readAsBytes();
            payload = await compute(convertImageToPng, bytes);
          } catch (e) {
            print("Failed to convert image: ${filePaths[i]} — $e");
            continue;
          }
        }

        final objectKey = "$_storeFolder/$uploadFolder/$fileName";
        final uploadUrl = await _uploadBytes(
          payload,
          objectKey,
          onProgress: (progress) {
            onProgress?.call(i + 1, filePaths.length, progress);
          },
          clientId: clientIdForThumb,
          fileNumber: i + 1,
        );
        if (uploadUrl != null) {
          uploadedUrls.add(uploadUrl);
        }
      }

      return S3UploadResult(
        urls: uploadedUrls,
        nextIdx: allocatedIdx,
        clientId: clientIdForThumb,
      );
    } catch (e) {
      print("Error uploading files: $e");
      return S3UploadResult(
        urls: uploadedUrls,
        nextIdx: allocatedIdx,
        clientId: clientIdForThumb,
      );
    }
  }

  static Future<String?> _uploadBytes(
    List<int> bytes,
    String objectKey, {
    Function(double progress)? onProgress,
    int? clientId,
    int fileNumber = 1,
  }) async {
    try {
      final contentType = _getContentType(objectKey);
      final headers = _signedHeaders(
        method: "PUT",
        objectKey: objectKey,
        contentType: contentType,
        payload: bytes,
      );

      final response = await _dio.put(
        "$_baseUrl/$objectKey",
        data: bytes,
        options: Options(headers: headers),
        onSendProgress: (sent, total) {
          final progress = total != 0 ? sent / total : 0.0;
          onProgress?.call(progress);
          print("Uploading $objectKey: ${(progress * 100).toStringAsFixed(1)}%");
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final url = "$_baseUrl/$objectKey";
        print("Uploaded: $url");

        if (clientId != null &&
            clientId > 0 &&
            fileNumber == 1 &&
            !_isVideoExtension(path.extension(objectKey))) {
          await _copyToClientBucket(bytes: bytes, clientId: clientId);
        }

        return url;
      }

      print("Upload failed for $objectKey: ${response.statusCode}");
      return null;
    } catch (e) {
      print("Error uploading $objectKey: $e");
      return null;
    }
  }

  static Future<void> _copyToClientBucket({
    required List<int> bytes,
    required int clientId,
  }) async {
    try {
      final clientObjectKey = "$_clientStoreFolder/$clientId.jpg";
      const contentType = "image/jpeg";

      final headers = _signedHeaders(
        method: "PUT",
        objectKey: clientObjectKey,
        contentType: contentType,
        payload: bytes,
        overrideHost: _clientHost,
      );

      final response = await _dio.put(
        "$_clientBaseUrl/$clientObjectKey",
        data: bytes,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Copied to client bucket: $_clientBaseUrl/$clientObjectKey");
      } else {
        print("❌ Copy failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error copying to client bucket: $e");
    }
  }

  static Future<bool> deleteFile(String remotePath) async {
    try {
      final objectKey = remotePath.startsWith("$_storeFolder/")
          ? remotePath
          : "$_storeFolder/$remotePath";
      final headers = _signedHeaders(
        method: "DELETE",
        objectKey: objectKey,
        contentType: "application/octet-stream",
        payload: const [],
      );

      final response = await _dio.delete(
        "$_baseUrl/$objectKey",
        options: Options(headers: headers),
      );

      return response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404;
    } catch (e) {
      print("Error deleting file: $e");
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
        "content-type:$contentType\n"
        "host:$hostToUse\n"
        "x-amz-content-sha256:$payloadHash\n"
        "x-amz-date:$amzDate\n";
    const signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date";

    final canonicalRequest =
        "$method\n"
        "$canonicalUri\n"
        "\n"
        "$canonicalHeaders\n"
        "$signedHeaders\n"
        "$payloadHash";

    final credentialScope = "$dateStamp/$_region/s3/aws4_request";
    final stringToSign =
        "AWS4-HMAC-SHA256\n"
        "$amzDate\n"
        "$credentialScope\n"
        "${sha256.convert(utf8.encode(canonicalRequest))}";

    final signingKey = _getSignatureKey(_secretKey, dateStamp, _region, "s3");
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();

    final authorization =
        "AWS4-HMAC-SHA256 "
        "Credential=$_accessKey/$credentialScope, "
        "SignedHeaders=$signedHeaders, "
        "Signature=$signature";

    return {
      "Authorization": authorization,
      "Content-Type": contentType,
      "x-amz-date": amzDate,
      "x-amz-content-sha256": payloadHash,
      "Host": hostToUse,
    };
  }

  static List<int> _getSignatureKey(
    String secretKey,
    String dateStamp,
    String region,
    String service,
  ) {
    final kDate = Hmac(sha256, utf8.encode("AWS4$secretKey"))
        .convert(utf8.encode(dateStamp))
        .bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode("aws4_request")).bytes;
  }

  static String _canonicalUri(String objectKey) {
    return "/${objectKey.split("/").map(Uri.encodeComponent).join("/")}";
  }

  static String _formatAmzDate(DateTime dateTime) {
    return "${dateTime.year.toString().padLeft(4, "0")}"
        "${dateTime.month.toString().padLeft(2, "0")}"
        "${dateTime.day.toString().padLeft(2, "0")}"
        "T"
        "${dateTime.hour.toString().padLeft(2, "0")}"
        "${dateTime.minute.toString().padLeft(2, "0")}"
        "${dateTime.second.toString().padLeft(2, "0")}"
        "Z";
  }

  static String _formatDateStamp(DateTime dateTime) {
    return "${dateTime.year.toString().padLeft(4, "0")}"
        "${dateTime.month.toString().padLeft(2, "0")}"
        "${dateTime.day.toString().padLeft(2, "0")}";
  }

  static String _getContentType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case ".jpg":
      case ".jpeg":
        return "image/jpeg";
      case ".png":
        return "image/png";
      case ".gif":
        return "image/gif";
      case ".webp":
        return "image/webp";
      case ".mp4":
        return "video/mp4";
      case ".mov":
        return "video/quicktime";
      case ".avi":
        return "video/x-msvideo";
      default:
        return "application/octet-stream";
    }
  }
}