import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/models/export_format.dart';
import 'package:gintoolflutter/src/models/loop_mode.dart';
import 'package:gintoolflutter/src/services/video_processor.dart';
import 'package:gintoolflutter/src/state/editor_controller.dart';

class _FakeProcessor implements VideoProcessor {
  @override
  Future<String> export(
    ExportRequest request, {
    required ProgressCallback onProgress,
  }) async {
    onProgress(1, 'ok');
    return request.outputPath;
  }

  @override
  Future<String> exportFrameJpeg(FrameExportRequest request) async {
    return request.outputPath;
  }

  @override
  Future<Duration> probeDuration(String inputPath) async =>
      const Duration(seconds: 30);
}

void main() {
  test('zoom=1.0でfit換算できる', () {
    final controller = EditorController(videoProcessor: _FakeProcessor());
    controller.setTotalDuration(const Duration(seconds: 10));

    final pps = controller.pixelsPerSecondForViewport(1000);
    expect(pps, closeTo(100.0, 0.0001));
  });

  test('初期ロードでstart=0/end=durationになる', () {
    final controller = EditorController(videoProcessor: _FakeProcessor());

    controller.setTotalDuration(const Duration(seconds: 12));

    expect(controller.trimStartSeconds, closeTo(0, 0.0001));
    expect(controller.trimEndSeconds, closeTo(12, 0.0001));
  });

  test('trim更新時にplayheadが範囲内へ補正される', () {
    final controller = EditorController(videoProcessor: _FakeProcessor());
    controller.setTotalDuration(const Duration(seconds: 10));
    controller.seekTo(8.0);

    controller.setTrimRange(startSeconds: 1.0, endSeconds: 4.0);

    expect(controller.trimStartSeconds, 1.0);
    expect(controller.trimEndSeconds, 4.0);
    expect(controller.playheadSeconds, inInclusiveRange(1.0, 4.0));
  });

  test('スクラブ用playhead更新は即時反映される', () {
    final controller = EditorController(videoProcessor: _FakeProcessor());
    controller.setTotalDuration(const Duration(seconds: 10));

    controller.setPlayheadFromScrub(3.75);

    expect(controller.playheadSeconds, closeTo(3.75, 0.0001));
  });

  test('GIF選択時にループ回数は1に固定される', () {
    final controller = EditorController(videoProcessor: _FakeProcessor());
    controller.setLoopCount(8);

    controller.setExportFormat(ExportFormat.gif);

    expect(controller.loopCount, 1);
  });

  test('書き出しリクエストに反映される', () async {
    final controller = EditorController(videoProcessor: _FakeProcessor());
    controller.setTotalDuration(const Duration(seconds: 10));
    controller.setTrimRange(startSeconds: 1.0, endSeconds: 5.0);
    controller.setLoopMode(LoopMode.pingPong);
    controller.setExportFormat(ExportFormat.mp4);
    controller.setLoopCount(4);

    final ok = await controller.export(
      inputPath: 'in.mp4',
      outputPath: 'out.mp4',
    );

    expect(ok, isTrue);
    expect(controller.lastOutputPath, 'out.mp4');
  });

  test('現在フレームのJPG書き出しが成功する', () async {
    final controller = EditorController(videoProcessor: _FakeProcessor());
    controller.setTotalDuration(const Duration(seconds: 10));

    final ok = await controller.exportCurrentFrameJpeg(
      inputPath: 'in.mp4',
      positionSeconds: 2.5,
      outputPath: 'frame.jpg',
    );

    expect(ok, isTrue);
    expect(controller.lastFrameOutputPath, 'frame.jpg');
  });
}
