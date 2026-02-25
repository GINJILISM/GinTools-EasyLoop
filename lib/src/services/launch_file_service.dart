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
    final method = call.method;
    if (method != 'onOpenFile' && method != 'onReceiveSharedMedia') {
      return;
    }

    final paths = _extractIncomingPaths(call.arguments);
    for (final rawPath in paths) {
      final file = File(rawPath);
      if (!_importService.isSupportedVideoFile(file)) {
        continue;
      }
      _openedFileController.add(file.path);
      break;
    }
  }

  List<String> _extractIncomingPaths(dynamic args) {
    final resolved = <String>[];

    void appendPath(dynamic candidate) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        resolved.add(candidate);
      }
    }

    if (args is String) {
      appendPath(args);
      return resolved;
    }

    if (args is Map) {
      appendPath(args['path']);
      final rawPaths = args['paths'];
      if (rawPaths is List) {
        for (final path in rawPaths) {
          appendPath(path);
        }
      }
      return resolved;
    }

    if (args is List) {
      for (final item in args) {
        appendPath(item);
      }
    }

    return resolved;
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
