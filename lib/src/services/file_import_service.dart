import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class FileImportService {
  static const List<String> supportedExtensions = <String>[
    'mp4',
    'mov',
    'm4v',
    'avi',
    'mkv',
    'webm',
  ];

  final ImagePicker _imagePicker = ImagePicker();
  bool _isPhotoLibraryRequestInFlight = false;

  bool isVideoPath(String path) {
    final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
    return supportedExtensions.contains(extension);
  }

  bool isSupportedVideoFile(File file) {
    return file.existsSync() && isVideoPath(file.path);
  }

  String? validateVideoPath(String? path) {
    if (path == null || path.trim().isEmpty) {
      return '動画ファイルが選択されていません。';
    }
    if (!isVideoPath(path)) {
      return '未対応のファイル形式です。対応形式: ${supportedExtensions.join(', ')}';
    }
    return null;
  }

  Future<String?> pickVideoFromFileApp({
    String dialogTitle = '動画ファイルを選択',
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
      allowMultiple: false,
      dialogTitle: dialogTitle,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.single.path;
  }

  Future<String?> pickVideoFromPhotoLibrary() async {
    if (_isPhotoLibraryRequestInFlight) {
      return null;
    }

    _isPhotoLibraryRequestInFlight = true;
    try {
      final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
      return picked?.path;
    } on PlatformException catch (error) {
      if (error.code == 'multiple_request') {
        return null;
      }
      rethrow;
    } finally {
      _isPhotoLibraryRequestInFlight = false;
    }
  }
}
