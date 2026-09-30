import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:iconsax/iconsax.dart";
import "package:video_player/video_player.dart";

import "../utils/item_media_url_util.dart";

/// Product thumbnail that works for both images and videos.
/// Tries still-image URLs first, then falls back to a muted first-frame video.
class ItemThumbnailWidget extends StatefulWidget {
  final String? storeId;
  final String itemId;
  final String? itemIdx;
  final String? preferredUrl;
  final String? mediaToken;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? placeholderColor;
  final double iconSize;
  final bool showPlayBadge;

  const ItemThumbnailWidget({
    super.key,
    required this.itemId,
    this.storeId,
    this.itemIdx,
    this.preferredUrl,
    this.mediaToken,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderColor,
    this.iconSize = 30,
    this.showPlayBadge = true,
  });

  @override
  State<ItemThumbnailWidget> createState() => _ItemThumbnailWidgetState();
}

class _ItemThumbnailWidgetState extends State<ItemThumbnailWidget> {
  List<String> _candidates = [];
  int _candidateIndex = 0;
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _tryingVideo = false;

  @override
  void initState() {
    super.initState();
    _candidates = ItemMediaUrlUtil.thumbnailCandidates(
      storeId: widget.storeId,
      itemId: widget.itemId,
      itemIdx: widget.itemIdx,
      preferredUrl: widget.preferredUrl,
      mediaToken: widget.mediaToken,
    );
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ItemThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId ||
        oldWidget.itemIdx != widget.itemIdx ||
        oldWidget.storeId != widget.storeId ||
        oldWidget.preferredUrl != widget.preferredUrl) {
      _disposeVideo();
      _candidateIndex = 0;
      _videoReady = false;
      _tryingVideo = false;
      _candidates
        ..clear()
        ..addAll(
          ItemMediaUrlUtil.thumbnailCandidates(
            storeId: widget.storeId,
            itemId: widget.itemId,
            itemIdx: widget.itemIdx,
            preferredUrl: widget.preferredUrl,
            mediaToken: widget.mediaToken,
          ),
        );
      _bootstrap();
    }
  }

  void _bootstrap() {
    if (_candidates.isEmpty) return;
    final first = _candidates.first;
    if (ItemMediaUrlUtil.isVideoUrl(first)) {
      _loadVideo(first);
    }
  }

  Future<void> _loadVideo(String url) async {
    _disposeVideo();
    _tryingVideo = true;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.seekTo(Duration.zero);
      await controller.pause();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _videoReady = true;
        _tryingVideo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tryingVideo = false;
        _videoReady = false;
      });
      _advanceCandidate();
    }
  }

  void _advanceCandidate() {
    if (_candidateIndex >= _candidates.length - 1) {
      return;
    }
    setState(() {
      _candidateIndex++;
    });
    final next = _candidates[_candidateIndex];
    if (ItemMediaUrlUtil.isVideoUrl(next)) {
      _loadVideo(next);
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  Widget _placeholder() {
    return Container(
      color: widget.placeholderColor ?? Colors.grey[800],
      child: Icon(
        Iconsax.image,
        color: Colors.grey,
        size: widget.iconSize,
      ),
    );
  }

  Widget _videoThumb() {
    if (!_videoReady || _videoController == null) {
      return _placeholder();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
        if (widget.showPlayBadge)
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.play,
                color: Colors.white,
                size: widget.iconSize * 0.55,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: _placeholder(),
      );
    }

    final url = _candidates[_candidateIndex];

    Widget child;
    if (ItemMediaUrlUtil.isVideoUrl(url)) {
      child = _tryingVideo && !_videoReady
          ? Container(
              color: widget.placeholderColor ?? Colors.grey[900],
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : _videoThumb();
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        placeholder: (_, __) => Container(
          color: widget.placeholderColor ?? Colors.grey[900],
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) {
          final canAdvance = _candidateIndex < _candidates.length - 1;
          if (canAdvance) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _advanceCandidate();
            });
          }
          return _placeholder();
        },
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }
}
