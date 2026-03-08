import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design/typography/app_font_roles.dart';
import '../../services/file_import_service.dart';
import '../liquid_glass/liquid_glass_refs.dart';
import '../app_strings.dart';
import '../widgets/liquid_glass_action_button.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.onVideoSelected});

  final ValueChanged<String> onVideoSelected;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final FileImportService _fileImportService = FileImportService();

  bool _dragging = false;
  bool _isPicking = false;
  String? _errorMessage;

  bool get _supportsDragDrop {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  Future<void> _pickFile() async {
    if (_isPicking) {
      return;
    }

    setState(() => _isPicking = true);
    try {
      final path = await _fileImportService.pickVideoFromFileApp(
        dialogTitle: AppStrings.fileAppVideoPickerTitle,
      );
      await _handlePickedPath(path);
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _openLibrary() async {
    if (_isPicking) {
      return;
    }

    setState(() => _isPicking = true);
    try {
      final path = await _fileImportService.pickVideoFromPhotoLibrary();
      await _handlePickedPath(path);
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
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
    final primaryActionTextStyle = AppFontRoles.actionButtonLabel(
      Theme.of(context).textTheme.labelLarge,
    );
    final panel = Container(
      width: 860,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _dragging
            ? LiquidGlassRefs.surfaceCard.withValues(alpha: 0.9)
            : LiquidGlassRefs.surfaceCard,
        border: Border.all(
          color: _dragging
              ? LiquidGlassRefs.accentBlue
              : LiquidGlassRefs.outlineSoft,
          width: _dragging ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            AppStrings.importScreenTitle,
            style: AppFontRoles.screenHeadline(
              Theme.of(context).textTheme.headlineSmall,
            )?.copyWith(
              color: LiquidGlassRefs.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 166,
                child: LiquidGlassActionButton.icon(
                  onPressed: _isPicking ? null : _pickFile,
                  fillColor: LiquidGlassRefs.accentOrange,
                  foregroundColor: Colors.white,
                  borderColor: const Color(0x66CFE9FF),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text(AppStrings.openFromFile),
                  style: ButtonStyle(
                    textStyle: WidgetStatePropertyAll(primaryActionTextStyle),
                  ),
                ),
              ),
              SizedBox(
                width: 236,
                child: LiquidGlassActionButton.icon(
                  onPressed: _isPicking ? null : _openLibrary,
                  fillColor: LiquidGlassRefs.accentOrangeMuted,
                  foregroundColor: LiquidGlassRefs.textPrimary,
                  borderColor: const Color.fromARGB(80, 255, 255, 255),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text(AppStrings.openFromLibrary),
                  style: ButtonStyle(
                    textStyle: WidgetStatePropertyAll(primaryActionTextStyle),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.desktopDragAndDropHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LiquidGlassRefs.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
      backgroundColor: LiquidGlassRefs.editorBgBase,
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: content),
      ),
    );
  }
}
