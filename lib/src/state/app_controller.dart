import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/launch_file_service.dart';

class AppController extends ChangeNotifier {
  AppController({required this.launchFileService}) {
    _bootstrap();
  }

  final LaunchFileService launchFileService;
  StreamSubscription<String>? _openedFilesSubscription;

  String? _inputPath;
  int _sessionVersion = 0;

  String? get inputPath => _inputPath;
  int get sessionVersion => _sessionVersion;

  Future<void> _bootstrap() async {
    _inputPath = await launchFileService.getInitialFilePath();
    _openedFilesSubscription = launchFileService.watchOpenedFiles().listen(
      (path) => openInputPath(path, replaceCurrent: true),
    );
    notifyListeners();
  }

  void openInputPath(String path, {bool replaceCurrent = false}) {
    final isSamePath = _inputPath == path;
    _inputPath = path;
    if (replaceCurrent || isSamePath) {
      _sessionVersion += 1;
    }
    notifyListeners();
  }

  void closeEditor() {
    _inputPath = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _openedFilesSubscription?.cancel();
    launchFileService.dispose();
    super.dispose();
  }
}
