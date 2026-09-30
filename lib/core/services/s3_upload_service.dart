import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:image/image.dart" as img;
import "package:path/path.dart" as path;

Uint8List convertImageToWebP(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception("Failed to decode image");
  }
  return Uint8List.fromList(img.encodeWebP(decoded));
}

class S3UploadService {
  static const String _accessKey = "AKIARVJRTCELH4VUZZ73";
  static const String _secretKey = "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";
  static const String _region = "ap-south-1";
  static const String _bucket = "martit";
  static const String _baseUrl = "https://martit.s3.ap-south-1.amazonaws.com";
  static const String _storeFolder = "store_1";
  static const String _host = "martit.s3.ap-south-1.amazonaws.com";

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

  static Future<List<String>> uploadMediaFiles({
    required List<String> filePaths,
    required String itemId,
    int startIndex = 0,
    Function(int current, int total, double progress)? onProgress,
    Function(int fileIndex, String filePath, double progress)? onFileProgress,
  }) async {
    final uploadedUrls = <String>[];

    try {
      for (int i = 0; i < filePaths.length; i++) {
        final filePath = filePaths[i];
        final file = File(filePath);
        if (!file.existsSync()) continue;

        final extension = path.extension(filePath).toLowerCase();
        if (!_isImageExtension(extension) && !_isVideoExtension(extension)) {
          continue;
        }

        final String fileName;
        final List<int> payload;

        if (_isVideoExtension(extension)) {
          fileName = "${startIndex + i + 1}$extension";
          payload = await file.readAsBytes();
        } else {
          fileName = "${startIndex + i + 1}.webp";
          try {
            final bytes = await file.readAsBytes();
            payload = await compute(convertImageToWebP, bytes);
          } catch (e) {
            print("Failed to convert image: $filePath — $e");
            continue;
          }
        }

        onFileProgress?.call(i, filePath, 0.0);

        final objectKey = "$_storeFolder/$itemId/$fileName";
        final uploadUrl = await _uploadBytes(
          payload,
          objectKey,
          onProgress: (progress) {
            onProgress?.call(i + 1, filePaths.length, progress);
            onFileProgress?.call(i, filePath, progress);
          },
        );
        if (uploadUrl != null) {
          uploadedUrls.add(uploadUrl);
          onFileProgress?.call(i, filePath, 1.0);
        }
      }

      return uploadedUrls;
    } catch (e) {
      print("Error uploading files: $e");
      return [];
    }
  }

  static Future<String?> uploadProfileImage({
    required String userId,
    required String filePath,
    Function(double progress)? onProgress,
  }) async {
    if (userId.isEmpty) {
      print("Profile upload skipped: userId is empty");
      return null;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print("Profile upload skipped: file not found");
        return null;
      }

      final bytes = await file.readAsBytes();
      final webpBytes = await compute(convertImageToWebP, bytes);
      final objectKey = "Users/store_1/$userId/1.webp";

      return _uploadBytes(
        webpBytes,
        objectKey,
        contentType: "image/webp",
        onProgress: onProgress,
      );
    } catch (e) {
      print("Error uploading profile image: $e");
      return null;
    }
  }

  static Future<String?> uploadBytes({
    required List<int> bytes,
    required String objectKey,
    String? contentType,
    Function(double progress)? onProgress,
  }) async {
    return _uploadBytes(
      bytes,
      objectKey,
      contentType: contentType,
      onProgress: onProgress,
    );
  }

  static Future<String?> _uploadBytes(
    List<int> bytes,
    String objectKey, {
    String? contentType,
    Function(double progress)? onProgress,
  }) async {
    try {
      final resolvedContentType = contentType ?? _getContentType(objectKey);
      final headers = _signedHeaders(
        method: "PUT",
        objectKey: objectKey,
        contentType: resolvedContentType,
        payload: bytes,
      );

      final response = await _dio.put(
        "$_baseUrl/$objectKey",
        data: bytes,
        options: Options(headers: headers),
        onSendProgress: (sent, total) {
          final progress = total != 0 ? sent / total : 0.0;
          onProgress?.call(progress);
          print(
            "Uploading $objectKey: ${(progress * 100).toStringAsFixed(1)}%",
          );
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final url = "$_baseUrl/$objectKey";
        print("Uploaded: $url");
        return url;
      }

      print("Upload failed for $objectKey: ${response.statusCode}");
      return null;
    } catch (e) {
      print("Error uploading $objectKey: $e");
      return null;
    }
  }

  /// Deletes an S3 object. Accepts a full URL, object key, or store-relative path.
  /// Examples:
  /// - `https://martit.s3.ap-south-1.amazonaws.com/store_1/31284/5.mp4`
  /// - `store_1/31284/5.mp4`
  /// - `31284/5.mp4` (prefixed with store folder)
  static Future<bool> deleteFile(String remotePathOrUrl) async {
    try {
      final objectKey = resolveObjectKey(remotePathOrUrl);
      if (objectKey == null || objectKey.isEmpty) {
        print("Delete skipped: could not resolve object key from $remotePathOrUrl");
        return false;
      }

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

      final ok = response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404;
      if (ok) {
        print("Deleted: $_baseUrl/$objectKey");
      } else {
        print("Delete failed for $objectKey: ${response.statusCode}");
      }
      return ok;
    } catch (e) {
      print("Error deleting file: $e");
      return false;
    }
  }

  static String? resolveObjectKey(String remotePathOrUrl) {
    final trimmed = remotePathOrUrl.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;
      final path = uri.path.startsWith("/") ? uri.path.substring(1) : uri.path;
      return path.isEmpty ? null : path;
    }

    if (trimmed.startsWith("$_baseUrl/")) {
      return trimmed.substring(_baseUrl.length + 1);
    }

    if (trimmed.startsWith("$_storeFolder/")) {
      return trimmed;
    }

    return "$_storeFolder/$trimmed";
  }

  static String mediaObjectKey({
    required String itemId,
    required String fileName,
  }) {
    return "$_storeFolder/$itemId/$fileName";
  }

  static String mediaUrl({
    required String itemId,
    required String fileName,
  }) {
    return "$_baseUrl/${mediaObjectKey(itemId: itemId, fileName: fileName)}";
  }

  static Map<String, String> _signedHeaders({
    required String method,
    required String objectKey,
    required String contentType,
    required List<int> payload,
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);
    final payloadHash = sha256.convert(payload).toString();
    final canonicalUri = _canonicalUri(objectKey);

    final canonicalHeaders =
        "content-type:$contentType\n"
        "host:$_host\n"
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
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();

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
      "Host": _host,
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
      utf8.encode("AWS4$secretKey"),
    ).convert(utf8.encode(dateStamp)).bytes;
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
