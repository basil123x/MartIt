import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:iconsax/iconsax.dart';
import '../constants/app_colors.dart';

const String _s3BaseUrl = 'https://martit.s3.ap-south-1.amazonaws.com';
const int _maxS3Images = 10;

/// GES media on martit S3: store_3/{folder}/1.png, 2.png, ...
String s3MediaImageUrl(String folder, int fileNumber) {
  return '$_s3BaseUrl/store_3/$folder/$fileNumber.png';
}

/// Probe 1.png … 10.png; stop at the first missing file (sequential numbering).
Future<List<String>> discoverS3MediaUrls(String folder) async {
  if (folder.isEmpty) return [];

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  final urls = <String>[];
  for (int n = 1; n <= _maxS3Images; n++) {
    final url = s3MediaImageUrl(folder, n);
    try {
      final response = await dio.head(url);
      if (response.statusCode == 200) {
        urls.add(url);
      } else {
        break;
      }
    } catch (_) {
      break;
    }
  }
  return urls;
}

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

  List<String> _s3Urls = [];
  bool _loading = true;

  String get _folder =>
      widget.itmIdx.isNotEmpty ? widget.itmIdx : widget.itmId;

  @override
  void initState() {
    super.initState();
    _loadS3Media();
  }

  Future<void> _loadS3Media() async {
    final urls = await discoverS3MediaUrls(_folder);
    if (!mounted) return;
    setState(() {
      _s3Urls = urls;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_folder.isEmpty) {
      return _emptyPlaceholder();
    }

    if (_loading) {
      return const ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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

    if (_s3Urls.isEmpty) {
      return _emptyPlaceholder();
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemCount: _s3Urls.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: _s3Urls[index],
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                color: Colors.black,
                child: const Center(
                  child: SpinKitPulse(color: AppColors.white),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.black,
                child: const Icon(
                  Iconsax.image,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
        if (widget.showIndicators && _s3Urls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_s3Urls.length, (index) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _emptyPlaceholder() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
}
