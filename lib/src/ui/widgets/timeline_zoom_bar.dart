import 'package:flutter/material.dart';

class TimelineZoomBar extends StatelessWidget {
  const TimelineZoomBar({
    super.key,
    required this.zoomLevel,
    required this.onChanged,
  });

  final double zoomLevel;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text('タイムライン倍率'),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: zoomLevel,
            min: 0.5,
            max: 5.0,
            divisions: 45,
            label: '${zoomLevel.toStringAsFixed(1)}x',
            onChanged: onChanged,
          ),
        ),
        Text('${zoomLevel.toStringAsFixed(1)}x'),
      ],
    );
  }
}
