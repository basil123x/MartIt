import "package:flutter/material.dart";
import "package:iconsax/iconsax.dart";

import "../../core/widgets/smart_avatar_widget.dart";
import '../../core/utils/theme_extensions.dart';

class ProfileAvatarPreviewScreen extends StatefulWidget {
  final String userId;
  final String name;
  final bool loadSocialFromStorage;
  final String? fallbackUrl;
  final int? cacheTimestamp;
  final String heroTag;

  const ProfileAvatarPreviewScreen({
    super.key,
    required this.userId,
    required this.name,
    this.loadSocialFromStorage = false,
    this.fallbackUrl,
    this.cacheTimestamp,
    this.heroTag = "profile_avatar",
  });

  @override
  State<ProfileAvatarPreviewScreen> createState() =>
      _ProfileAvatarPreviewScreenState();
}

class _ProfileAvatarPreviewScreenState extends State<ProfileAvatarPreviewScreen> {
  double _dragOffset = 0;

  void _dismiss() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final previewSize = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffset += details.delta.dy;
          });
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset > 80 || (details.primaryVelocity ?? 0) > 300) {
            _dismiss();
          } else {
            setState(() {
              _dragOffset = 0;
            });
          }
        },
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Opacity(
            opacity: (1 - (_dragOffset.abs() / 300)).clamp(0.3, 1.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: _dismiss,
                  behavior: HitTestBehavior.opaque,
                  child: const ColoredBox(color: Colors.black),
                ),
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: SmartAvatarWidget(
                      userId: widget.userId,
                      name: widget.name,
                      size: previewSize,
                      loadSocialFromStorage: widget.loadSocialFromStorage,
                      fallbackUrl: widget.fallbackUrl,
                      cacheTimestamp: widget.cacheTimestamp,
                      heroTag: widget.heroTag,
                      fit: BoxFit.cover,
                      clipOval: true,
                      backgroundColor: const Color(0xFF2A2A2A),
                      initialsStyle: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: previewSize * 0.35,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: _dismiss,
                      icon: const Icon(
                        Iconsax.close_circle,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
