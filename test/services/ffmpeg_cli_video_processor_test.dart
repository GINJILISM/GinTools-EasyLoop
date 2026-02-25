import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/models/gif_export_options.dart';
import 'package:gintoolflutter/src/services/ffmpeg_cli_video_processor.dart';
import 'package:gintoolflutter/src/services/video_processor.dart';

void main() {
  group('FfmpegCliVideoProcessor', () {
    final processor = FfmpegCliVideoProcessor();

    test('GIF用コマンドにpalettegen/paletteuse/-loop 0が含まれる', () {
      final paletteArgs = processor.buildGifPaletteArgs(
        inputPath: 'cycle.mp4',
        palettePath: 'palette.png',
        fps: 24,
        qualityPreset: GifQualityPreset.medium,
      );
      final renderArgs = processor.buildGifRenderArgs(
        inputPath: 'cycle.mp4',
        palettePath: 'palette.png',
        outputPath: 'out.gif',
        fps: 24,
        qualityPreset: GifQualityPreset.medium,
      );

      expect(paletteArgs.join(' '), contains('palettegen'));
      expect(renderArgs.join(' '), contains('paletteuse'));
      expect(renderArgs, contains('-filter_complex'));
      expect(renderArgs, containsAll(<String>['-map', '[gif]']));
      expect(renderArgs, contains('-loop'));
      expect(renderArgs, contains('0'));
    });

    test('JPGフレーム書き出しは最高品質設定で生成される', () {
      final args = processor.buildFrameJpegArgs(
        request: FrameExportRequest(
          inputPath: 'in.mp4',
          outputPath: 'frame.jpg',
          position: const Duration(milliseconds: 1234),
        ),
      );

      expect(args, containsAll(<String>['-map', '0:v:0', '-frames:v', '1']));
      expect(args, containsAll(<String>['-q:v', '2', '-f', 'image2']));
      expect(args.last, 'frame.jpg');
    });
  });
}
