import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/ui/widgets/trim_timeline.dart';

void main() {
  testWidgets('サムネイル未生成でもスクラブで再生位置を更新できる', (tester) async {
    final updates = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 220,
            child: TrimTimeline(
              totalDuration: const Duration(seconds: 12),
              trimStartSeconds: 0,
              trimEndSeconds: 10,
              playheadSeconds: 0,
              zoomLevel: 1.0,
              thumbnails: const [],
              onSeek: (seconds) {},
              onTrimChanged: (start, end) {},
              onScrubUpdate: updates.add,
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('trim-timeline-surface')),
      const Offset(220, 0),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(updates, isNotEmpty);
    expect(updates.last, greaterThan(0));
  });
}
