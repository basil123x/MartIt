class ItemMediaUrlUtil {
  static const String baseUrl = "https://martit.s3.ap-south-1.amazonaws.com";
  static const List<String> imageExtensions = ["webp", "png", "jpg", "jpeg"];
  static const List<String> videoExtensions = ["mp4", "mov", "avi"];

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

  static bool isVideoUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase().split("?")[0];
    return videoExtensions.any((ext) => lower.endsWith(".$ext"));
  }

  static bool isImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase().split("?")[0];
    return imageExtensions.any((ext) => lower.endsWith(".$ext"));
  }

  /// Extract extension from a media token like `1.mp4`, `2.webp`, or a full URL.
  static String? extensionFromMediaToken(String token) {
    final clean = token.trim().toLowerCase().split("?")[0].split("]").first;
    final match = RegExp(r"\.([a-z0-9]+)$").firstMatch(clean);
    if (match == null) return null;
    final ext = match.group(1)!;
    if (imageExtensions.contains(ext) || videoExtensions.contains(ext)) {
      // Images are stored as webp on S3.
      if (ext == "png" || ext == "jpg" || ext == "jpeg") return "webp";
      return ext;
    }
    return null;
  }

  static String mediaUrl({
    required String? storeId,
    required String itemId,
    String? itemIdx,
    int index = 1,
    String extension = "webp",
  }) {
    final store = normalizeStoreId(storeId);
    final pathKey = resolveItemPathKey(itemIdx: itemIdx, itemId: itemId);
    final safeIndex = index < 1 ? 1 : index;
    final ext = extension.startsWith(".") ? extension.substring(1) : extension;
    return "$baseUrl/store_$store/$pathKey/$safeIndex.$ext";
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

  /// Candidate thumbnail URLs for an item (image first, then video).
  static List<String> thumbnailCandidates({
    required String? storeId,
    required String itemId,
    String? itemIdx,
    String? preferredUrl,
    String? mediaToken,
  }) {
    final urls = <String>[];

    void add(String? url) {
      if (url == null || url.trim().isEmpty) return;
      final clean = url.trim().split("]")[0];
      if (!urls.contains(clean)) urls.add(clean);
    }

    add(preferredUrl);

    final tokenExt = mediaToken == null
        ? null
        : extensionFromMediaToken(mediaToken);
    if (tokenExt != null) {
      add(
        mediaUrl(
          storeId: storeId,
          itemId: itemId,
          itemIdx: itemIdx,
          index: 1,
          extension: tokenExt,
        ),
      );
    }

    // Prefer still image, then common video containers.
    add(mediaUrl(storeId: storeId, itemId: itemId, itemIdx: itemIdx, extension: "webp"));
    add(mediaUrl(storeId: storeId, itemId: itemId, itemIdx: itemIdx, extension: "mp4"));
    add(mediaUrl(storeId: storeId, itemId: itemId, itemIdx: itemIdx, extension: "mov"));

    return urls;
  }
}
