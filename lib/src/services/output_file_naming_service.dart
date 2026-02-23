import 'dart:io';

import 'package:path/path.dart' as p;

class OutputFileNamingService {
  static const String defaultTemplate = '{looptype}_{filename}';

  static final RegExp _invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  static final RegExp _trailingDotsAndSpaces = RegExp(r'[. ]+$');
  static final RegExp _windowsReserved = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
    caseSensitive: false,
  );

  String normalizeTemplate(String? template) {
    final trimmed = template?.trim() ?? '';
    if (trimmed.isEmpty) {
      return defaultTemplate;
    }
    return trimmed;
  }

  Future<String> buildOutputPath({
    required String directoryPath,
    required String inputFilePath,
    required String loopType,
    required String extension,
    String? template,
  }) async {
    final normalizedTemplate = normalizeTemplate(template);
    final normalizedExtension = _normalizeExtension(extension);

    final sourceBaseName = _sanitizeFileNameComponent(
      p.basenameWithoutExtension(inputFilePath).trim(),
      fallback: 'input',
    );
    final loopTypeName = _sanitizeFileNameComponent(
      loopType.trim(),
      fallback: 'loop',
    );

    var baseName = normalizedTemplate
        .replaceAll('{looptype}', loopTypeName)
        .replaceAll('{filename}', sourceBaseName);
    baseName = _sanitizeFileNameComponent(
      baseName,
      fallback: '$loopTypeName\_$sourceBaseName',
    );

    await Directory(directoryPath).create(recursive: true);

    final basePath = p.join(directoryPath, '$baseName.$normalizedExtension');
    return _resolveCollision(basePath);
  }

  Future<String> _resolveCollision(String path) async {
    if (!await File(path).exists()) {
      return path;
    }

    final directory = p.dirname(path);
    final extension = p.extension(path);
    final baseName = p.basenameWithoutExtension(path);

    for (var i = 1; i < 10000; i++) {
      final suffix = i.toString().padLeft(3, '0');
      final candidate = p.join(directory, '$baseName\_$suffix$extension');
      if (!await File(candidate).exists()) {
        return candidate;
      }
    }

    throw StateError('Unable to find unique output path for $path');
  }

  String _normalizeExtension(String extension) {
    final trimmed = extension.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(extension, 'extension', 'must not be empty');
    }
    return trimmed.startsWith('.') ? trimmed.substring(1) : trimmed;
  }

  String _sanitizeFileNameComponent(String value, {required String fallback}) {
    var sanitized = value.replaceAll(_invalidChars, '_');
    sanitized = sanitized.replaceAll(_trailingDotsAndSpaces, '');
    sanitized = sanitized.trim();

    if (sanitized.isEmpty) {
      sanitized = fallback;
    }
    if (_windowsReserved.hasMatch(sanitized)) {
      sanitized = '${sanitized}_';
    }
    return sanitized;
  }
}
