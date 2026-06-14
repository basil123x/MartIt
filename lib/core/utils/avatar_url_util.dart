class AvatarUrlUtil {
  static const String _s3Base =
      'https://martit.s3.ap-south-1.amazonaws.com/Users/store_1';

  static String s3Path(String userId) => '$_s3Base/$userId/1.png';

  static String displayUrl(String userId, {int? timestamp}) {
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    return '${s3Path(userId)}?t=$ts';
  }

  static String withCacheBust(String url, {int? timestamp}) {
    if (url.isEmpty) return url;
    final base = url.split('?').first;
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    return '$base?t=$ts';
  }

  static String cacheKey(String userId) => '$userId-${DateTime.now().day}';

  static String resolveDisplayUrl({
    required String userId,
    String? storedUrl,
    int? timestamp,
  }) {
    if (userId.isNotEmpty) {
      return displayUrl(userId, timestamp: timestamp);
    }
    if (storedUrl != null && storedUrl.isNotEmpty) {
      return withCacheBust(storedUrl, timestamp: timestamp);
    }
    return '';
  }
}
