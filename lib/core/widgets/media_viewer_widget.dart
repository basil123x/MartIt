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

  // static Future<List<String>> _fetchMedia(String itemId, String foldId) async {
  //   try {
  //     final response = await Dio().get(
  //       'https://albadaa-qatar.com/2026/works/stores/invoices/imgup/get_items_media.php',
  //       queryParameters: {
  //         'item_id': itemId,
  //         'folderId': foldId,
  //         'secret': "Albadaa_UPLOAD_SECRET_2026",
  //       },
  //     );
  //     if (response.statusCode == 200 && response.data['success'] == true) {
  //       final media = response.data['media'] as List;
  //       return media.map((e) => e['url'] as String).toList();
  //     }
  //     return [];
  //   } catch (e) {
  //     return [];
  //   }
  // }


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: 1,
              itemBuilder: (context, index) {
                return _buildSingleMedia(
                  widget.itmIdx != '' ? "https://albadaa-qatar.com/2026/works/stores/invoices/imgup/itmx/${widget.itmIdx}.png" : "https://albadaa-qatar.com/2026/works/stores/invoices/imgup/itmapp/${widget.itmId}/1.png",
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

  Widget _buildSingleMedia(
    String url,
    String itmId,
    String itmIdx,
    String storeid,
    int index
  ) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          color: Colors.black,
          child: const Center(child: SpinKitPulse(color: AppColors.white)),
        ),
      );
  }
}
