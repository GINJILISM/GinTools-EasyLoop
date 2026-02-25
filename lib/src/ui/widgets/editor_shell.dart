import 'package:flutter/material.dart';

enum EditorOpenSource { filesApp, photoLibrary }

class EditorShell extends StatelessWidget {
  const EditorShell({
    super.key,
    required this.title,
    required this.preview,
    required this.timeline,
    required this.controls,
    required this.onOpenSourceSelected,
    this.showDropHighlight = false,
  });

  final String title;
  final Widget preview;
  final Widget timeline;
  final Widget controls;
  final ValueChanged<EditorOpenSource> onOpenSourceSelected;
  final bool showDropHighlight;

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

    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w500);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '\u7de8\u96c6\u4e2d: $title',
          style: titleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          PopupMenuButton<EditorOpenSource>(
            tooltip: '\u52d5\u753b\u3092\u958B\u304F',
            onSelected: onOpenSourceSelected,
            itemBuilder: (context) => const <PopupMenuEntry<EditorOpenSource>>[
              PopupMenuItem<EditorOpenSource>(
                value: EditorOpenSource.filesApp,
                child: ListTile(
                  leading: Icon(Icons.folder_open_rounded),
                  title: Text('\u30D5\u30A1\u30A4\u30EB\u30A2\u30D7\u30EA\u304B\u3089\u958B\u304F'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<EditorOpenSource>(
                value: EditorOpenSource.photoLibrary,
                child: ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('\u5199\u771F\u30E9\u30A4\u30D6\u30E9\u30EA\u304B\u3089\u958B\u304F'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            child: isCompact
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.video_library_outlined),
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.video_library_outlined),
                        SizedBox(width: 6),
                        Text('\u52d5\u753b\u3092\u958B\u304F'),
                      ],
                    ),
                  ),
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
