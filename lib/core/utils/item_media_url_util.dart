class ItemMediaUrlUtil {
  static const String baseUrl = "https://martit.s3.ap-south-1.amazonaws.com";

  static String normalizeStoreId(String? storeId) {
    final value = storeId?.trim() ?? "";
    return value.isEmpty ? "1" : value;
  }

  /// S3 object folder uses [itemIdx] when set; otherwise falls back to [itemId].
  static String resolveItemPathKey({
    required String? itemIdx,
    required String itemId,
  }) {
    final idx = itemIdx?.trim() ?? "";
    if (idx.isNotEmpty) return idx;
    final id = itemId.trim();
    return id.isNotEmpty ? id : "1";
  }

  static String mediaUrl({
    required String? storeId,
    required String itemId,
    String? itemIdx,
    int index = 1,
  }) {
    final store = normalizeStoreId(storeId);
    final pathKey = resolveItemPathKey(itemIdx: itemIdx, itemId: itemId);
    final safeIndex = index < 1 ? 1 : index;
    return "$baseUrl/store_$store/$pathKey/$safeIndex.png";
  }

  static String thumbnail({
    required String? storeId,
    required String itemId,
    String? itemIdx,
  }) {
    return mediaUrl(
      storeId: storeId,
      itemId: itemId,
      itemIdx: itemIdx,
      index: 1,
    );
  }
}
