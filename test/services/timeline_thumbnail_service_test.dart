import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/services/timeline_thumbnail_service.dart';

void main() {
  group('TimelineThumbnailService', () {
    final service = TimelineThumbnailService();

    test('viewportWidth と zoomLevel で targetCount が変わる', () {
      final fitCount = service.computeTargetCount(
        viewportWidth: 960,
        zoomLevel: 1.0,
        tileBaseWidth: 96,
      );
      final zoomedCount = service.computeTargetCount(
        viewportWidth: 960,
        zoomLevel: 2.0,
        tileBaseWidth: 96,
      );

      expect(fitCount, 10);
      expect(zoomedCount, 20);
    });

    test('targetCount は下限6・上限180で丸められる', () {
      final minCount = service.computeTargetCount(
        viewportWidth: 100,
        zoomLevel: 0.5,
        tileBaseWidth: 96,
      );
      final maxCount = service.computeTargetCount(
        viewportWidth: 4000,
        zoomLevel: 10.0,
        tileBaseWidth: 96,
      );

      expect(minCount, 6);
      expect(maxCount, 180);
    });

    test('キャッシュキーは zoom と viewport で分離される', () {
      final keyA = service.buildCacheKey(
        inputPath: 'a.mp4',
        fileStamp: 1,
        durationMs: 4000,
        zoomLevel: 1.0,
        viewportWidth: 800,
        tileBaseWidth: 96,
      );
      final keyB = service.buildCacheKey(
        inputPath: 'a.mp4',
        fileStamp: 1,
        durationMs: 4000,
        zoomLevel: 1.5,
        viewportWidth: 800,
        tileBaseWidth: 96,
      );
      final keyC = service.buildCacheKey(
        inputPath: 'a.mp4',
        fileStamp: 1,
        durationMs: 4000,
        zoomLevel: 1.0,
        viewportWidth: 1200,
        tileBaseWidth: 96,
      );

      expect(keyA, isNot(equals(keyB)));
      expect(keyA, isNot(equals(keyC)));
    });
  });
}
