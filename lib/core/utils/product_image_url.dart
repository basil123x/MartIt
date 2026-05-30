import '../constants/app_constants.dart';

/// Product image URLs. Albadaa (store 4) uses martit store_4/{idx}/N.png (idx = S3 folder).
class ProductImageUrl {
  static const String baseUrl = 'https://martit.s3.ap-south-1.amazonaws.com';

  static bool isAlbadaaStore(String storeId) =>
      storeId == AppConstants.albadaaStoreId;

  /// S3 folder for store_4: idx when set, otherwise fallback to Globee id.
  static String albadaaS3FolderId({required String idx, required String id}) {
    final folder = idx.trim();
    if (folder.isNotEmpty && folder != '0') {
      return folder;
    }
    return id.trim();
  }

  /// store_4/{idx}/1.png
  static String albadaaImageUrl({
    required String idx,
    required String id,
    int index = 1,
  }) {
    final folder = albadaaS3FolderId(idx: idx, id: id);
    return '$baseUrl/store_5/$folder/$index.png';
  }

  static int albadaaImageCountFromField(String? mediaField) {
    if (mediaField == null || mediaField.trim().isEmpty) {
      return 1;
    }
    final parts = mediaField
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();
    return parts.isEmpty ? 1 : parts.length;
  }

  static List<String> albadaaMediaUrls({
    required String idx,
    required String id,
    String? mediaField,
    int? imageCount,
  }) {
    final count = imageCount ?? albadaaImageCountFromField(mediaField);
    final safeCount = count < 1 ? 1 : count;
    return List.generate(
      safeCount,
      (i) => albadaaImageUrl(idx: idx, id: id, index: i + 1),
    );
  }

  static String build({
    required String storeId,
    required String itemId,
    required String itemIdx,
    int index = 1,
    String? mediaFilename,
  }) {
    if (isAlbadaaStore(storeId)) {
      return albadaaImageUrl(idx: itemIdx, id: itemId, index: index);
    }

    final file = mediaFilename ?? '$index.png';
    return 'https://martit.s3.ap-south-1.amazonaws.com/store_5/$itemIdx/1.png';
  }

  static List<String> mediaList({
    required String storeId,
    required String itemId,
    required String itemIdx,
    String? mediaField,
  }) {
    if (isAlbadaaStore(storeId)) {
      return albadaaMediaUrls(idx: itemIdx, id: itemId, mediaField: mediaField);
    }

    if (mediaField == null || mediaField.trim().isEmpty) {
      return [build(storeId: storeId, itemId: itemId, itemIdx: itemIdx)];
    }

    final files = mediaField
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    if (files.isEmpty) {
      return [build(storeId: storeId, itemId: itemId, itemIdx: itemIdx)];
    }

    return files
        .map(
          (f) => build(
            storeId: storeId,
            itemId: itemId,
            itemIdx: itemIdx,
            mediaFilename: f,
          ),
        )
        .toList();
  }

  static List<String> feedMediaUrls({
    required String storeId,
    required String itemId,
    required String itemIdx,
    List<String> apiMedia = const [],
    String? mediaField,
  }) {
    if (isAlbadaaStore(storeId)) {
      return albadaaMediaUrls(
        idx: itemIdx,
        id: itemId,
        mediaField: mediaField,
        imageCount: apiMedia.isEmpty ? null : apiMedia.length,
      );
    }
    if (apiMedia.isNotEmpty) {
      return apiMedia;
    }
    return mediaList(
      storeId: storeId,
      itemId: itemId,
      itemIdx: itemIdx,
      mediaField: mediaField,
    );
  }
}
