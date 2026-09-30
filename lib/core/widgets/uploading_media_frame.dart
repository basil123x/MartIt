import 'dart:io';

import 'package:flutter/material.dart';

import '../services/background_media_upload_service.dart';
import '../utils/item_media_url_util.dart';

/// Shows a local preview plus the lime upload ring while a product's media
/// is still uploading in the background.
class UploadingMediaFrame extends StatefulWidget {
  final String itemId;
  final Widget ready;

  const UploadingMediaFrame({
    super.key,
    required this.itemId,
    required this.ready,
  });

  @override
  State<UploadingMediaFrame> createState() => _UploadingMediaFrameState();
}

class _UploadingMediaFrameState extends State<UploadingMediaFrame> {
  final BackgroundMediaUploadService _uploads =
      BackgroundMediaUploadService.instance;

  @override
  void initState() {
    super.initState();
    _uploads.addListener(_onUploadsChanged);
  }

  @override
  void dispose() {
    _uploads.removeListener(_onUploadsChanged);
    super.dispose();
  }

  void _onUploadsChanged() {
    if (mounted) setState(() {});
  }

  bool _isVideo(String path) {
    final clean = path.toLowerCase().split('?').first;
    return ItemMediaUrlUtil.isVideoUrl(clean) ||
        clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.m4v');
  }

  @override
  Widget build(BuildContext context) {
    if (!_uploads.isUploading(widget.itemId)) {
      return widget.ready;
    }

    final paths = _uploads.previewPaths(widget.itemId);
    final progress = _uploads.progressOf(widget.itemId);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (paths.isEmpty)
          const ColoredBox(color: Colors.black)
        else if (paths.length == 1)
          _preview(paths.first)
        else
          PageView.builder(
            itemCount: paths.length,
            itemBuilder: (_, index) => _preview(paths[index]),
          ),
        const ColoredBox(color: Color(0x59000000)),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shortest = constraints.biggest.shortestSide;
              final ring = shortest.isFinite
                  ? (shortest * 0.22).clamp(36.0, 84.0)
                  : 64.0;
              return SizedBox(
                width: ring,
                height: ring,
                child: CircularProgressIndicator(
                  value: (progress > 0 && progress < 1) ? progress : null,
                  strokeWidth: 3.5,
                  color: const Color(0xFFC6FF3D),
                  backgroundColor: Colors.white24,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _preview(String path) {
    if (_isVideo(path)) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.videocam_rounded, color: Colors.white70, size: 42),
        ),
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return const ColoredBox(color: Colors.black);
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
    );
  }
}
