import 'package:flutter/material.dart';

class PreviewStage extends StatelessWidget {
  const PreviewStage({
    super.key,
    required this.video,
    required this.positionLabel,
    required this.isPingPong,
    required this.isReverseDirection,
    this.bottomOverlay,
  });

  final Widget video;
  final String positionLabel;
  final bool isPingPong;
  final bool isReverseDirection;
  final Widget? bottomOverlay;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: Colors.black, child: video),
          Positioned(
            top: 14,
            left: 14,
            right: isPingPong ? 130 : 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.56),
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
          if (isPingPong)
            Positioned(
              top: 14,
              right: 14,
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  isReverseDirection ? 'ピンポン: 逆方向' : 'ピンポン: 順方向',
                ),
              ),
            ),
          if (bottomOverlay != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: bottomOverlay!,
              ),
            ),
        ],
      ),
    );
  }
}
