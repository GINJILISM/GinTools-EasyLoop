import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/services/launch_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('起動引数から初期パスを取得できる', () async {
    final file = File('${Directory.systemTemp.path}/launch_file_test.mp4');
    await file.writeAsString('x');

    final service = LaunchFileService(
      startupArgs: <String>['dummy.txt', file.path],
    );
    await service.initialize();

    final initial = await service.getInitialFilePath();
    expect(initial, file.path);

    await service.dispose();
    await file.delete();
  });


  test('共有シート想定の複数パス受信でも最初の動画を通知できる', () async {
    final invalid = File('${Directory.systemTemp.path}/launch_file_stream_test.txt');
    final valid = File('${Directory.systemTemp.path}/launch_file_share_test.mov');
    await invalid.writeAsString('x');
    await valid.writeAsString('x');

    final service = LaunchFileService(startupArgs: const <String>[]);
    await service.initialize();

    final future = service.watchOpenedFiles().first;
    await service.handleIncomingPathForTest(invalid.path);
    await service.handleIncomingPathForTest(valid.path);

    expect(await future, valid.path);

    await service.dispose();
    await invalid.delete();
    await valid.delete();
  });

  test('ランタイム受信でストリーム通知される', () async {
    final file = File(
      '${Directory.systemTemp.path}/launch_file_stream_test.mp4',
    );
    await file.writeAsString('x');

    final service = LaunchFileService(startupArgs: const <String>[]);
    await service.initialize();

    final future = service.watchOpenedFiles().first;
    await service.handleIncomingPathForTest(file.path);

    expect(await future, file.path);

    await service.dispose();
    await file.delete();
  });
}
