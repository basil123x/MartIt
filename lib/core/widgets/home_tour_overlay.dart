import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/localization_service.dart';

class HomeTourStep {
  final GlobalKey? targetKey;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final bool preferCircle;
  final bool showSwipeHint;

  const HomeTourStep({
    this.targetKey,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    this.preferCircle = true,
    this.showSwipeHint = false,
  });

  String title(String lang) => lang == 'ar' ? titleAr : titleEn;
  String body(String lang) => lang == 'ar' ? bodyAr : bodyEn;
}

/// Full-screen coach-mark tour with a spotlight hole around each target.
class HomeTourOverlay extends StatefulWidget {
  final List<HomeTourStep> steps;
  final VoidCallback onFinish;

  const HomeTourOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  @override
  State<HomeTourOverlay> createState() => _HomeTourOverlayState();
}

class _HomeTourOverlayState extends State<HomeTourOverlay>
    with TickerProviderStateMixin {
  int _index = 0;
  Rect? _hole;
  late final AnimationController _pulse;
  late final AnimationController _swipeHint;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _swipeHint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureCurrent());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _swipeHint.dispose();
    super.dispose();
  }

  HomeTourStep get _step => widget.steps[_index];

  void _measureCurrent() {
    if (!mounted) return;
    final key = _step.targetKey;

    // Welcome / no-target step.
    if (key == null) {
      setState(() => _hole = null);
      return;
    }

    // Skip steps whose target is not currently on screen (e.g. More when logged out).
    if (key.currentContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_index >= widget.steps.length - 1) {
          widget.onFinish();
        } else {
          _next();
        }
      });
      return;
    }

    final box = key.currentContext!.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      setState(() => _hole = null);
      return;
    }
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final pad = _step.preferCircle ? 10.0 : 8.0;
    setState(() {
      _hole = Rect.fromLTWH(
        offset.dx - pad,
        offset.dy - pad,
        size.width + pad * 2,
        size.height + pad * 2,
      );
    });
  }

  Future<void> _next() async {
    if (_index >= widget.steps.length - 1) {
      widget.onFinish();
      return;
    }
    setState(() {
      _index++;
      _hole = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 40));
    _measureCurrent();
  }

  void _skip() => widget.onFinish();

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    final isAr = lang == 'ar';
    final size = MediaQuery.sizeOf(context);
    final step = _step;
    final total = widget.steps.length;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SpotlightPainter(
                      hole: _hole,
                      preferCircle: step.preferCircle,
                      pulse: _pulse.value,
                    ),
                    foregroundPainter: _hole == null
                        ? null
                        : _RingPainter(
                            hole: _hole!,
                            preferCircle: step.preferCircle,
                            pulse: _pulse.value,
                          ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
          if (step.showSwipeHint && _hole != null) _buildSwipeHintArrow(),
          _buildTooltipCard(
            context: context,
            lang: lang,
            isAr: isAr,
            screenSize: size,
            step: step,
            total: total,
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeHintArrow() {
    final hole = _hole!;
    return Positioned(
      left: hole.center.dx - 30,
      top: hole.center.dy - 10,
      width: 60,
      height: 100,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _swipeHint,
          builder: (context, _) {
            // Move upward + fade — TikTok-style "swipe up for next"
            final t = _swipeHint.value;
            final dy = -Curves.easeInOut.transform(t) * 42;
            final opacity = t < 0.12
                ? t / 0.12
                : t > 0.72
                ? (1 - t) / 0.28
                : 1.0;

            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_up_rounded,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 40,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.swipe_up_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTooltipCard({
    required BuildContext context,
    required String lang,
    required bool isAr,
    required Size screenSize,
    required HomeTourStep step,
    required int total,
  }) {
    final cardWidth = math.min(320.0, screenSize.width - 32);
    double top;
    if (_hole == null) {
      top = screenSize.height * 0.35;
    } else {
      final below = _hole!.bottom + 16;
      final above = _hole!.top - 190;
      if (below + 180 < screenSize.height - 24) {
        top = below;
      } else if (above > MediaQuery.paddingOf(context).top + 8) {
        top = above;
      } else {
        top = screenSize.height * 0.32;
      }
    }

    double left = (screenSize.width - cardWidth) / 2;
    if (_hole != null) {
      left = (_hole!.center.dx - cardWidth / 2).clamp(16.0, screenSize.width - cardWidth - 16);
    }

    return Positioned(
      top: top.clamp(
        MediaQuery.paddingOf(context).top + 12,
        screenSize.height - 220,
      ),
      left: left,
      width: cardWidth,
      child: Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Container(
            key: ValueKey(_index),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_index + 1} / $total',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(40, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(isAr ? 'تخطي' : 'Skip'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step.title(lang),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.body(lang),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _index >= total - 1
                          ? (isAr ? 'ابدأ الآن' : 'Get started')
                          : (isAr ? 'التالي' : 'Next'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  final bool preferCircle;
  final double pulse;

  _SpotlightPainter({
    required this.hole,
    required this.preferCircle,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      final cut = Path();
      if (preferCircle) {
        final r = math.max(hole!.width, hole!.height) / 2 + 4;
        cut.addOval(Rect.fromCircle(center: hole!.center, radius: r));
      } else {
        cut.addRRect(
          RRect.fromRectAndRadius(hole!, const Radius.circular(16)),
        );
      }
      final path = Path.combine(PathOperation.difference, overlay, cut);
      canvas.drawPath(
        path,
        Paint()..color = Colors.black.withValues(alpha: 0.72),
      );
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.hole != hole ||
        oldDelegate.preferCircle != preferCircle ||
        oldDelegate.pulse != pulse;
  }
}

class _RingPainter extends CustomPainter {
  final Rect hole;
  final bool preferCircle;
  final double pulse;

  _RingPainter({
    required this.hole,
    required this.preferCircle,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.primary.withValues(alpha: 0.55 + pulse * 0.35);

    if (preferCircle) {
      final r = math.max(hole.width, hole.height) / 2 + 6 + pulse * 4;
      canvas.drawCircle(hole.center, r, paint);
    } else {
      final inflated = hole.inflate(4 + pulse * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inflated, const Radius.circular(16)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.hole != hole ||
        oldDelegate.preferCircle != preferCircle ||
        oldDelegate.pulse != pulse;
  }
}
