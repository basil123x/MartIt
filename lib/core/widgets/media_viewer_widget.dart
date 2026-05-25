import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../constants/app_constants.dart';
import '../utils/product_image_url.dart';
import 'video_player_widget.dart';

class MediaViewerWidget extends StatefulWidget {
  final List<String> mediaUrls;
  final String itmId;
  final String itmIdx;
  final String storeid;
  final bool autoPlayVideo;
  final bool showControls;
  final bool showIndicators;

  const MediaViewerWidget({
    super.key,
    required this.mediaUrls,
    required this.itmId,
    required this.itmIdx,
    required this.storeid,
    this.autoPlayVideo = true,
    this.showControls = false,
    this.showIndicators = true,
  });

  @override
  State<MediaViewerWidget> createState() => _MediaViewerWidgetState();
}

class _MediaViewerWidgetState extends State<MediaViewerWidget> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  List<String> get _urls {
    final storeId = widget.storeid.isNotEmpty ? widget.storeid : '4';
    final resolved = ProductImageUrl.feedMediaUrls(
      storeId: storeId,
      itemId: widget.itmId,
      itemIdx: widget.itmIdx,
      apiMedia: widget.mediaUrls,
    );
    if (resolved.isNotEmpty) {
      return resolved;
    }
    return [
      ProductImageUrl.albadaaImageUrl(
        idx: widget.itmIdx,
        id: widget.itmId,
      ),
    ];
  }

  String get _primaryImageUrl {
    final urls = _urls;
    return urls.first;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    final imageUrl = _primaryImageUrl;
    debugPrint('🖼️ MediaViewer primary URL: $imageUrl (count=${urls.length})');

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (urls.length <= 1)
            _buildFeedImage(imageUrl)
          else
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: urls.length,
              itemBuilder: (context, index) {
                return _buildFeedImage(urls[index]);
              },
            ),
          if (widget.showIndicators && urls.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedImage(String imageUrl) {
    debugPrint('🖼️ Image URL: $imageUrl');

    if (imageUrl.isEmpty) {
      debugPrint('❌ Image URL is empty — widget not loading');
      return Container(
        color: Colors.orange,
        alignment: Alignment.center,
        child: const Icon(Iconsax.image, color: Colors.white, size: 48),
      );
    }

    final isVideo =
        imageUrl.contains('.mp4') || imageUrl.contains('.mov');

    if (isVideo) {
      return SizedBox.expand(
        child: VideoPlayerWidget(
          networkUrl: imageUrl,
          autoPlay: widget.autoPlayVideo,
          showControls: widget.showControls,
        ),
      );
    }

    final storeId = widget.storeid.isNotEmpty
        ? widget.storeid
        : AppConstants.albadaaStoreId;
    final imageFit = storeId == AppConstants.albadaaStoreId
        ? BoxFit.contain
        : BoxFit.cover;

    return SizedBox.expand(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: imageFit,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            color: Colors.white54,
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('❌ Image load error: $error for $url');
          return Container(
            color: Colors.red,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconsax.image, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    url,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
