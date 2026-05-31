import "package:cached_network_image/cached_network_image.dart";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_spinkit/flutter_spinkit.dart";
import "package:iconsax/iconsax.dart";

import "../constants/app_colors.dart";
import "video_player_widget.dart";

class MediaViewerWidget extends StatefulWidget {
  static const String s3BaseUrl = "https://martit.s3.ap-south-1.amazonaws.com";

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
  static const int _maxImages = 20;

  final PageController _pageController = PageController();
  final Dio _dio = Dio();
  int _currentIndex = 0;
  late Future<List<String>> _mediaFuture;

  @override
  void initState() {
    super.initState();
    _mediaFuture = _resolveMediaUrlsDeferred();
  }

  @override
  void didUpdateWidget(MediaViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itmId != widget.itmId ||
        oldWidget.itmIdx != widget.itmIdx ||
        oldWidget.storeid != widget.storeid) {
      _mediaFuture = _resolveMediaUrlsDeferred();
    }
  }

  Future<List<String>> _resolveMediaUrlsDeferred() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return [];
    }
    return _resolveMediaUrls();
  }

  String _mediaUrl(int index, String ext) {
    return "${MediaViewerWidget.s3BaseUrl}/store_${widget.storeid}/${widget.itmIdx != "" ? widget.itmIdx : widget.itmId}/$index.$ext";
  }

  Future<bool> _urlExists(String url) async {
    try {
      final response = await _dio.head(
        url,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint("MediaViewerWidget: HEAD failed for $url: $e");
      return false;
    }
  }

  Future<List<String>> _resolveMediaUrls() async {
    final urls = <String>[];
    const extensions = ["png", "mp4", "mov"];

    for (int index = 1; index <= _maxImages; index++) {
      bool foundAny = false;

      for (final ext in extensions) {
        final url = _mediaUrl(index, ext);
        if (await _urlExists(url)) {
          urls.add(url);
          foundAny = true;
        }
      }

      if (!foundAny) {
        break;
      }
    }

    for (final mediaUrl in widget.mediaUrls) {
      final normalized = mediaUrl.split("]")[0];
      if (_isVideoUrl(normalized) && !urls.contains(normalized)) {
        urls.add(normalized);
      }
    }

    return urls;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideoUrl(String url) {
    return url.toLowerCase().endsWith(".mp4") ||
        url.toLowerCase().endsWith(".mov") ||
        url.toLowerCase().endsWith(".avi");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _mediaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.black,
            child: const Center(child: SpinKitPulse(color: AppColors.white)),
          );
        }

        final resolvedUrls = snapshot.data ?? [];

        if (resolvedUrls.isEmpty) {
          return Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Iconsax.image, size: 64, color: Colors.grey),
            ),
          );
        }

        if (resolvedUrls.length == 1) {
          return _buildSingleMedia(
            resolvedUrls.first,
            widget.itmId,
            widget.itmIdx,
            widget.storeid,
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
              itemCount: resolvedUrls.length,
              itemBuilder: (context, index) {
                return _buildSingleMedia(
                  resolvedUrls[index],
                  widget.itmId,
                  widget.itmIdx,
                  widget.storeid,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSingleMedia(
    String url,
    String itmId,
    String itmIdx,
    String storeid,
  ) {
    final urlx = url;
    String finalFullUrl = urlx.toString().split("]")[0];
    if (_isVideoUrl(finalFullUrl)) {
      return VideoPlayerWidget(
        networkUrl: finalFullUrl,
        autoPlay: widget.autoPlayVideo,
        showControls: widget.showControls,
      );
    } else {
      return CachedNetworkImage(
        imageUrl: finalFullUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          color: Colors.black,
          child: const Center(child: SpinKitPulse(color: AppColors.white)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.image, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  "فشل في تحميل الصورة",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
