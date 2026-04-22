import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:iconsax/iconsax.dart';
import '../constants/app_colors.dart';
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

    if (widget.mediaUrls.length == 1) {
      return _buildSingleMedia(
        widget.mediaUrls.first,
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
          itemCount: widget.mediaUrls.length,
          itemBuilder: (context, index) {
            return _buildSingleMedia(
              widget.mediaUrls[index],
              widget.itmId,
              widget.itmIdx,
              widget.storeid,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSingleMedia(
    String url,
    String itmId,
    String itmIdx,
    String storeid,
  ) {
    String ext = url.toString().split('/').last;
    String urlx = url;
    String imgUrl = "";
    String compName = "";
    print("IIIIIIII $itmIdx");
    switch (storeid) {
      case "2":
        compName = "GlobalFarm";
        imgUrl = itmIdx != ''
            ? "https://globalfarmnursery.s3.ap-south-1.amazonaws.com/items/$itmIdx.png"
            : "https://globee.b-cdn.net/$compName/$itmId/$ext";
        break;
      case "3":
        compName = "GES";
        imgUrl = itmIdx != ''
            ? "https://ges.qa/gesqatar/sys2025/attx/itmx/$itmIdx.png"
            : "https://globee.b-cdn.net/$compName/$itmId/$ext";
        break;
      default:
        imgUrl = "https://globee.b-cdn.net/$itmId/$ext";
        break;
    }
    String finalFullUrl = urlx.replaceAll(url, imgUrl);
    if (_isVideoUrl(finalFullUrl.toString().split(']')[0])) {
      return VideoPlayerWidget(
        networkUrl: finalFullUrl.toString().split(']')[0],
        autoPlay: widget.autoPlayVideo,
        showControls: widget.showControls,
      );
    } else {
      return CachedNetworkImage(
        imageUrl: finalFullUrl.toString().split(']')[0],
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
                  'فشل في تحميل الصورة',
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
