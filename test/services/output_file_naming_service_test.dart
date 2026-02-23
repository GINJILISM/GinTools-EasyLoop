import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/services/output_file_naming_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late OutputFileNamingService service;
  late Directory tempDir;

  setUp(() async {
    service = OutputFileNamingService();
    tempDir = await Directory.systemTemp.createTemp('output_naming_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('テンプレートを展開して拡張子を自動付与する', () async {
    final path = await service.buildOutputPath(
      directoryPath: tempDir.path,
      inputFilePath: p.join(tempDir.path, 'sample.mov'),
      loopType: 'loop',
      extension: 'mp4',
      template: '{looptype}_{filename}',
    );

    expect(p.basename(path), 'loop_sample.mp4');
  });

  test('禁止文字をサニタイズする', () async {
    final path = await service.buildOutputPath(
      directoryPath: tempDir.path,
      inputFilePath: p.join(tempDir.path, 'sa:mp*le?.mov'),
      loopType: 'pingpongLoop',
      extension: '.gif',
      template: '{looptype}_{filename}',
    );

    expect(p.basename(path), endsWith('.gif'));
    expect(
      RegExp(
        r'[<>:"/\\|?*\x00-\x1F]',
      ).hasMatch(p.basenameWithoutExtension(path)),
      isFalse,
    );
  });

  test('同名ファイルがある場合は連番で退避する', () async {
    final existing = File(p.join(tempDir.path, 'loop_sample.mp4'));
    await existing.writeAsString('already-exists');

    final path = await service.buildOutputPath(
      directoryPath: tempDir.path,
      inputFilePath: p.join(tempDir.path, 'sample.mov'),
      loopType: 'loop',
      extension: 'mp4',
      template: '{looptype}_{filename}',
    );

    expect(p.basename(path), 'loop_sample_001.mp4');
  });

  test('空テンプレート時はデフォルトにフォールバックする', () async {
    final path = await service.buildOutputPath(
      directoryPath: tempDir.path,
      inputFilePath: p.join(tempDir.path, 'clip.mp4'),
      loopType: 'snapshot',
      extension: 'jpg',
      template: '   ',
    );

    expect(p.basename(path), 'snapshot_clip.jpg');
  });
}
