import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../liquid_glass/liquid_glass_refs.dart';
import 'interactive_liquid_glass_icon_button.dart';

class EditorShell extends StatelessWidget {
  const EditorShell({
    super.key,
    required this.title,
    required this.preview,
    required this.timeline,
    required this.controls,
    required this.onImportDefaultRequested,
    required this.onImportFromFilesRequested,
    required this.onImportFromLibraryRequested,
    this.showDropHighlight = false,
  });

  final String title;
  final Widget preview;
  final Widget timeline;
  final Widget controls;
  final VoidCallback onImportDefaultRequested;
  final VoidCallback onImportFromFilesRequested;
  final VoidCallback onImportFromLibraryRequested;
  final bool showDropHighlight;

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _showImportSourceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('ライブラリから選択'),
                onTap: () {
                  Navigator.of(context).pop();
                  onImportFromLibraryRequested();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: const Text('ファイルから選択'),
                onTap: () {
                  Navigator.of(context).pop();
                  onImportFromFilesRequested();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImportPlusButton({
    required Key buttonKey,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return InteractiveLiquidGlassIconButton(
      buttonKey: buttonKey,
      icon: Icons.add_rounded,
      tooltip: tooltip,
      isDisabled: false,
      onPressed: onPressed,
      useLiquidGlass: LiquidGlassRefs.supportsLiquidGlass,
      backgroundColor: LiquidGlassRefs.accentBlue,
      foregroundColor: LiquidGlassRefs.textPrimary,
    );
  }

  Widget _buildSectionCard({required Widget child, required bool isCompact}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: LiquidGlassRefs.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LiquidGlassRefs.outlineSoft),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 8 : 12),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 420;
    final previewGap = isCompact ? 4.0 : 6.0;
    final cardsGap = isCompact ? 6.0 : 8.0;
    final timelineCardHeight = isCompact ? 132.0 : 168.0;
    final controlCardHeight = isCompact ? 112.0 : 138.0;

    final body = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 2 : 3,
      ),
      child: Column(
        children: <Widget>[
          Expanded(child: preview),
          SizedBox(height: previewGap),
          SizedBox(
            height: timelineCardHeight,
            child: _buildSectionCard(
              isCompact: isCompact,
              child: timeline,
            ),
          ),
          SizedBox(height: cardsGap),
          SizedBox(
            height: controlCardHeight,
            child: _buildSectionCard(
              isCompact: isCompact,
              child: SingleChildScrollView(child: controls),
            ),
          ),
        ],
      ),
    );

    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: LiquidGlassRefs.textPrimary,
        );
    final isMobilePlatform = _isMobilePlatform;

    return Scaffold(
      backgroundColor: LiquidGlassRefs.editorBgBase,
      appBar: AppBar(
        toolbarHeight: isMobilePlatform ? 52 : 50,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: isMobilePlatform
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: LiquidGlassRefs.surfaceDeep,
                  borderRadius: BorderRadius.circular(66),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    'Editing: $title',
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
        actions: <Widget>[
          if (isMobilePlatform)
            Row(
              children: <Widget>[
                _buildImportPlusButton(
                  buttonKey: const Key('import-video-mobile-plus-button'),
                  tooltip: '動画を追加',
                  onPressed: onImportDefaultRequested,
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '読み込み方法を選択',
                  onPressed: () {
                    _showImportSourceSheet(context);
                  },
                  icon: const Icon(Icons.arrow_drop_down),
                ),
              ],
            )
          else
            _buildImportPlusButton(
              buttonKey: Key(
                isCompact
                    ? 'import-video-compact-plus-button'
                    : 'import-video-plus-button',
              ),
              tooltip: '動画を追加',
              onPressed: onImportFromFilesRequested,
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: <Widget>[
          body,
          if (showDropHighlight)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: LiquidGlassRefs.accentBlue.withValues(alpha: 0.18),
                    border: Border.all(
                      color: LiquidGlassRefs.accentBlue,
                      width: 3,
                    ),
                  ),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text('ここにドロップして動画を置き換え'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
