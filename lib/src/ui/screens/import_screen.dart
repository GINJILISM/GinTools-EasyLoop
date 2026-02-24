import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/file_import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.onVideoSelected});

  final ValueChanged<String> onVideoSelected;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final FileImportService _fileImportService = FileImportService();

  bool _dragging = false;
  String? _errorMessage;

  bool get _supportsDragDrop {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  Future<void> _pickFile() async {
    final path = await _fileImportService.pickVideoFile();
    await _handlePickedPath(path);
  }

  Future<void> _handlePickedPath(String? path) async {
    final validationError = _fileImportService.validateVideoPath(path);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() => _errorMessage = null);
    widget.onVideoSelected(path!);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final panel = Container(
      width: 860,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _dragging
            ? colorScheme.primaryContainer.withOpacity(0.70)
            : colorScheme.surface.withOpacity(0.88),
        border: Border.all(
          color: _dragging ? colorScheme.primary : colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.video_library_rounded,
            size: 84,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            '動画をここへドロップ',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'または「動画を選択」から開くと、すぐにトリミング編集画面へ移動します。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('動画を選択'),
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    final content = _supportsDragDrop
        ? DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (details) async {
              setState(() => _dragging = false);
              if (details.files.isEmpty) return;
              await _handlePickedPath(details.files.first.path);
            },
            child: panel,
          )
        : panel;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF19466A), Color(0xFF0E253A)],
          ),
        ),
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: content),
        ),
      ),
    );
  }
}
