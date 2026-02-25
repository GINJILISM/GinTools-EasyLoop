import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
                title: const Text('ライブラリから取り込み'),
                onTap: () {
                  Navigator.of(context).pop();
                  onImportFromLibraryRequested();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: const Text('ファイルから取り込み'),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 420;

    final body = Padding(
      padding: EdgeInsets.all(isCompact ? 8 : 12),
      child: Column(
        children: <Widget>[
          Expanded(flex: isCompact ? 5 : 6, child: preview),
          SizedBox(height: isCompact ? 8 : 12),
          Expanded(
            flex: isCompact ? 5 : 4,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final timelineHeight = (constraints.maxHeight * 0.45).clamp(
                    64.0,
                    isCompact ? 140.0 : 180.0,
                  );
                  return Padding(
                    padding: EdgeInsets.all(isCompact ? 8 : 12),
                    child: Column(
                      children: <Widget>[
                        SizedBox(height: timelineHeight, child: timeline),
                        SizedBox(height: isCompact ? 6 : 8),
                        Expanded(child: SingleChildScrollView(child: controls)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    final isMobilePlatform = _isMobilePlatform;

    return Scaffold(
      appBar: AppBar(
        title: isMobilePlatform
            ? null
            : Text(
                '\u7de8\u96c6\u4e2d: $title',
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: <Widget>[
          if (isMobilePlatform)
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onImportDefaultRequested,
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('動画を選択'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '取り込み元を選択',
                  onPressed: () {
                    _showImportSourceSheet(context);
                  },
                  icon: const Icon(Icons.arrow_drop_down),
                ),
              ],
            )
          else if (isCompact)
            IconButton(
              tooltip: '\u52d5\u753b\u3092\u9078\u629e',
              onPressed: onImportFromFilesRequested,
              icon: const Icon(Icons.video_library_outlined),
            )
          else
            TextButton.icon(
              onPressed: onImportFromFilesRequested,
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('\u52d5\u753b\u3092\u9078\u629e'),
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
                    color: Colors.lightBlueAccent.withOpacity(0.18),
                    border: Border.all(color: Colors.lightBlueAccent, width: 3),
                  ),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text(
                            '\u3053\u3053\u306b\u30c9\u30ed\u30c3\u30d7\u3057\u3066\u52d5\u753b\u3092\u7f6e\u304d\u63db\u3048'),
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
