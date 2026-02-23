import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'file_import_service.dart';

class LaunchFileService {
  LaunchFileService({
    required List<String> startupArgs,
    FileImportService? importService,
    MethodChannel? channel,
  }) : _startupArgs = startupArgs,
       _importService = importService ?? FileImportService(),
       _channel =
           channel ??
           const MethodChannel('com.gintoolflutter.launch/open_file');

  final List<String> _startupArgs;
  final FileImportService _importService;
  final MethodChannel _channel;
  final StreamController<String> _openedFileController =
      StreamController<String>.broadcast();

  String? _initialPath;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    _initialPath = _resolveInitialPath();
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<String?> getInitialFilePath() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _initialPath;
  }

  Stream<String> watchOpenedFiles() => _openedFileController.stream;

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _openedFileController.close();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onOpenFile') {
      return;
    }

    String? rawPath;
    final args = call.arguments;
    if (args is Map) {
      final value = args['path'];
      rawPath = value is String ? value : null;
    } else if (args is String) {
      rawPath = args;
    }
    if (rawPath == null || rawPath.trim().isEmpty) {
      return;
    }

    final file = File(rawPath);
    if (!_importService.isSupportedVideoFile(file)) {
      return;
    }
    _openedFileController.add(file.path);
  }

  @visibleForTesting
  Future<void> handleIncomingPathForTest(String path) async {
    await _handleMethodCall(
      MethodCall('onOpenFile', <String, String>{'path': path}),
    );
  }

  String? _resolveInitialPath() {
    for (final rawArg in _startupArgs) {
      final file = File(rawArg);
      if (_importService.isSupportedVideoFile(file)) {
        return file.path;
      }
    }
    return null;
  }
}
