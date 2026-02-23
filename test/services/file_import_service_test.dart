import 'package:flutter_test/flutter_test.dart';
import 'package:gintoolflutter/src/services/file_import_service.dart';

void main() {
  group('FileImportService', () {
    final service = FileImportService();

    test('対応拡張子は許可される', () {
      expect(service.isVideoPath('a.mp4'), isTrue);
      expect(service.isVideoPath('a.mov'), isTrue);
      expect(service.isVideoPath('a.m4v'), isTrue);
      expect(service.isVideoPath('a.avi'), isTrue);
      expect(service.isVideoPath('a.mkv'), isTrue);
      expect(service.isVideoPath('a.webm'), isTrue);
    });

    test('非対応拡張子は拒否される', () {
      expect(service.isVideoPath('a.png'), isFalse);
      expect(service.validateVideoPath('a.png'), isNotNull);
    });
  });
}
