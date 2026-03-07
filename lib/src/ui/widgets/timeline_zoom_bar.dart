import 'package:flutter/material.dart';

import '../liquid_glass/liquid_glass_refs.dart';

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
    final activeColor = Color.fromRGBO(245, 107, 61, 0.6);
    final inactiveColor = LiquidGlassRefs.surfaceDeep.withValues(alpha: 0.55);
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: LiquidGlassRefs.textPrimary,
        );

    return Row(
      children: <Widget>[
        Text('タイムラインズーム', style: labelStyle),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: inactiveColor,
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.22),
              valueIndicatorColor:Color.fromRGBO(245, 107, 61, 0.6),
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              trackHeight: 4,
            ),
            child: Slider(
              value: zoomLevel,
              min: 0.5,
              max: 5.0,
              divisions: 45,
              label: '${zoomLevel.toStringAsFixed(1)}x',
              onChanged: onChanged,
            ),
          ),
        ),
        Text(
          '${zoomLevel.toStringAsFixed(1)}x',
          style: labelStyle,
        ),
      ],
    );
  }
}
