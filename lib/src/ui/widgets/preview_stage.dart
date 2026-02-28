import 'package:flutter/material.dart';

import '../liquid_glass/liquid_glass_refs.dart';

class PreviewStage extends StatelessWidget {
  const PreviewStage({
    super.key,
    required this.video,
    required this.positionLabel,
    required this.isPingPong,
    required this.isReverseDirection,
    this.bottomOverlay,
    this.centerOverlay,
  });

  final Widget video;
  final String positionLabel;
  final bool isPingPong;
  final bool isReverseDirection;
  final Widget? bottomOverlay;
  final Widget? centerOverlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: LiquidGlassRefs.editorBgBase,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                panEnabled: true,
                scaleEnabled: true,
                boundaryMargin: const EdgeInsets.all(80),
                child: SizedBox.expand(
                  child: ColoredBox(
                    color: Colors.transparent,
                    child: video,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    positionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            if (centerOverlay != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: centerOverlay!),
                ),
              ),
            if (bottomOverlay != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: bottomOverlay!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
