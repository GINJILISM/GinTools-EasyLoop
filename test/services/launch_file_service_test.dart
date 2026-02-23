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
