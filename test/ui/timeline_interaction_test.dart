import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/ui/widgets/trim_timeline.dart';

void main() {
  testWidgets('倍率1.0でfit幅が使われる', (tester) async {
    double viewport = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 220,
            child: TrimTimeline(
              totalDuration: const Duration(seconds: 10),
              trimStartSeconds: 1,
              trimEndSeconds: 7,
              playheadSeconds: 2,
              zoomLevel: 1.0,
              thumbnails: const [],
              onSeek: (seconds) {},
              onTrimChanged: (start, end) {},
              onViewportWidthChanged: (w) => viewport = w,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(viewport, closeTo(700, 2));
  });

  testWidgets('通常ドラッグでonScrubUpdateが連続発火する', (tester) async {
    final updates = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 220,
            child: TrimTimeline(
              totalDuration: const Duration(seconds: 10),
              trimStartSeconds: 1,
              trimEndSeconds: 7,
              playheadSeconds: 2,
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
      const Offset(140, 0),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(updates.length, greaterThan(1));
  });

  testWidgets('trimハンドル操作時はスクラブが干渉しない', (tester) async {
    double start = 1;
    double end = 7;
    var scrubCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 220,
            child: TrimTimeline(
              totalDuration: const Duration(seconds: 10),
              trimStartSeconds: start,
              trimEndSeconds: end,
              playheadSeconds: 2,
              zoomLevel: 1.0,
              thumbnails: const [],
              onSeek: (seconds) {},
              onTrimChanged: (nextStart, nextEnd) {
                start = nextStart;
                end = nextEnd;
              },
              onScrubUpdate: (_) => scrubCount++,
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('trim-handle-start')),
      const Offset(60, 0),
    );
    await tester.pump();

    expect(start, greaterThan(1));
    expect(end, 7);
    expect(scrubCount, 0);
  });
}
