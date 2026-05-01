import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:iconsax/iconsax.dart';
import '../constants/app_colors.dart';
import 'video_player_widget.dart';

final Map<String, Future<List<String>>> _mediaCache = {};

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

  late Future<List<String>> _mediaFuture;

  static Future<List<String>> _fetchMedia(String itemId, String foldId) async {
    try {
      final response = await Dio().get(
        'https://ges.qa/gesqatar/sys2026/attx/get_items_media.php',
        queryParameters: {
          'item_id': itemId,
          'folderId': foldId,
          'secret': "GES_UPLOAD_SECRET_2026",
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final media = response.data['media'] as List;
        return media.map((e) => e['url'] as String).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    final itemIdx = widget.itmIdx.toString();
    final itemId = widget.itmId.toString();
    print(itemId);
    print(itemIdx);
    _mediaFuture = _mediaCache.putIfAbsent(itemIdx != '' ? itemIdx : itemId, () => _fetchMedia(itemIdx != '' ? itemIdx : itemId, itemIdx != '' ? 'itmy' : 'itmapp'));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideoUrl(String url) {
    return url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov') ||
        url.toLowerCase().endsWith('.avi');
  }

  @override
  Widget build(BuildContext context) {
    

    if (widget.mediaUrls.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Iconsax.image, size: 64, color: Colors.grey),
        ),
      );
    }

    return FutureBuilder<List<String>>(
      future: _mediaFuture,
      builder: (context, snapshot) {
        // ── Loading ──
        if (snapshot.connectionState != ConnectionState.done) {
          return const ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }

        final mediaList = snapshot.data ?? [];
print(mediaList);
        // ── No media ──
        if (mediaList.isEmpty) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: Container(
              color: Colors.grey.shade200,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.grey,
                size: 40,
              ),
            ),
          );
        }
        
        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: mediaList.length,
              itemBuilder: (context, index) {
                return _buildSingleMedia(
                  mediaList[index],
                  widget.itmId,
                  widget.itmIdx,
                  widget.storeid,
                  index
                );
              },
            ),
          ],
        );
      }
    );
  }

  Widget _buildSingleMedia(
    String url,
    String itmId,
    String itmIdx,
    String storeid,
    int index
  ) {
    String ext = url.toString().split('/').last;
    String urlx = url;
    String imgUrl = "";
    String compName = "";
    if (itmIdx != '') {
      imgUrl = "https://ges.qa/gesqatar/sys2026/attx/itmy/$itmIdx/$index.png";
    } else {
      imgUrl = "https://ges.qa/gesqatar/sys2026/attx/itmapp/$itmId/${index+1}.jpg";
    }
    
      return CachedNetworkImage(
        imageUrl: imgUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          color: Colors.black,
          child: const Center(child: SpinKitPulse(color: AppColors.white)),
        ),
        errorWidget: (context, url, error) => Container(
          child: CachedNetworkImage(imageUrl: "https://ges.qa/gesqatar/sys2026/attx/itmy/$itmIdx/$index.jpg", fit: BoxFit.contain,placeholder: (context, url) => Container(
          color: Colors.black,
          child: const Center(child: SpinKitPulse(color: AppColors.white)),
        ),),
        ),
      );
  }
}
