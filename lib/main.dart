import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html2md/html2md.dart' as html2md;
import 'package:http/http.dart' as http;
import 'package:super_clipboard/super_clipboard.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _bg = Color(0xFF0F0F13);
const _surface = Color(0xFF17171D);
const _surfaceHigh = Color(0xFF1E1E26);
const _border = Color(0xFF2C2C38);
const _borderBright = Color(0xFF3E3E52);
const _gold = Color(0xFFC9A96E);
const _goldDim = Color(0xFF8A6F42);
const _ink = Color(0xFFE9E6DE);
const _inkMid = Color(0xFFA09D96);
const _inkDim = Color(0xFF5C5A56);
const _red = Color(0xFFE05C5C);

void main() {
  runApp(const MarkDApp());
}

// ── Mermaid segment parser ────────────────────────────────────────────────────
sealed class _Segment {
  const _Segment();
}

class _TextSegment extends _Segment {
  const _TextSegment(this.text);
  final String text;
}

class _MermaidSegment extends _Segment {
  const _MermaidSegment(this.code);
  final String code;
}

List<_Segment> _parseSegments(String text) {
  final result = <_Segment>[];
  final pattern = RegExp(r'```mermaid\r?\n([\s\S]*?)```', multiLine: true);
  int cursor = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      final chunk = text.substring(cursor, match.start);
      if (chunk.trim().isNotEmpty) result.add(_TextSegment(chunk));
    }
    final code = match.group(1) ?? '';
    if (code.trim().isNotEmpty) result.add(_MermaidSegment(code.trim()));
    cursor = match.end;
  }

  if (cursor < text.length) {
    final remaining = text.substring(cursor);
    if (remaining.trim().isNotEmpty) result.add(_TextSegment(remaining));
  }

  return result.isEmpty ? [_TextSegment(text)] : result;
}

// ── App ───────────────────────────────────────────────────────────────────────
class MarkDApp extends StatelessWidget {
  const MarkDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MarkD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          surface: _surface,
          primary: _gold,
          onPrimary: _bg,
          secondary: _goldDim,
          outline: _border,
        ),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(_border),
          trackColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

// ── Shell ─────────────────────────────────────────────────────────────────────
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _AppBar(index: _index, onTab: (i) => setState(() => _index = i)),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [EditorPage(), PasteToMarkdownPage()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.index, required this.onTab});
  final int index;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'MarkD',
            style: GoogleFonts.playfairDisplay(
              color: _gold,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 5,
            height: 5,
            decoration:
                const BoxDecoration(color: _gold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 28),
          _Tab(label: 'Editor', icon: Icons.edit_outlined, active: index == 0, onTap: () => onTab(0)),
          const SizedBox(width: 4),
          _Tab(label: 'RTF → MD', icon: Icons.transform_outlined, active: index == 1, onTap: () => onTab(1)),
          const Spacer(),
          Text('v1.0', style: GoogleFonts.jetBrainsMono(color: _inkDim, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.icon, required this.active, required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _gold.withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? _goldDim : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? _gold : _inkMid),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: active ? _gold : _inkMid,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editor Page ───────────────────────────────────────────────────────────────
class EditorPage extends StatefulWidget {
  const EditorPage({super.key});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _controller = TextEditingController(
    text: '# Welcome to MarkD\n'
        '\n'
        'Type Markdown on the left — preview renders live on the right.\n'
        '\n'
        '## Features\n'
        '\n'
        '- **Bold**, _italic_, and `inline code`\n'
        '- [Links](https://flutter.dev) and images\n'
        '- Tables, blockquotes, and fenced code blocks\n'
        '- Mermaid diagrams (rendered live)\n'
        '\n'
        '> A blockquote stands apart from the flow.\n'
        '\n'
        '```dart\n'
        'void main() => print(\'Hello MarkD\');\n'
        '```\n'
        '\n'
        '## Mermaid Diagram\n'
        '\n'
        '```mermaid\n'
        'flowchart LR\n'
        '    A[Write Markdown] --> B{Has mermaid?}\n'
        '    B -->|Yes| C[Render diagram]\n'
        '    B -->|No| D[Render markdown]\n'
        '    C --> E[Save .md]\n'
        '    D --> E\n'
        '```\n'
        '\n'
        '## Sequence Diagram\n'
        '\n'
        '```mermaid\n'
        'sequenceDiagram\n'
        '    participant User\n'
        '    participant MarkD\n'
        '    User->>MarkD: Type Markdown\n'
        '    MarkD-->>User: Live preview\n'
        '    User->>MarkD: Save .md\n'
        '    MarkD-->>User: File saved\n'
        '```\n',
  );

  bool _splitView = true;
  double _splitRatio = 0.5;

  Future<void> _saveMarkdown() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      _snack('Nothing to save yet.');
      return;
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: const [XTypeGroup(label: 'Markdown', extensions: ['md'])],
      suggestedName: 'document.md',
    );
    final path = location?.path;
    if (path == null) return;
    final targetPath = path.toLowerCase().endsWith('.md') ? path : '$path.md';
    final fileData = Uint8List.fromList(text.codeUnits);
    final mdFile = XFile.fromData(fileData, mimeType: 'text/markdown', name: targetPath.split('/').last);
    await mdFile.saveTo(targetPath);
    if (!mounted) return;
    _snack('Saved → $targetPath');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans(color: _ink, fontSize: 13)),
        backgroundColor: _surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _border),
        ),
        width: 460,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EditorToolbar(
          splitView: _splitView,
          onSplitChanged: (v) => setState(() => _splitView = v),
          onSave: _saveMarkdown,
          onClear: () => setState(() => _controller.clear()),
        ),
        const _HairLine(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final editor = _MarkdownEditor(controller: _controller);
              final preview = ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (_, val, __) => _MarkdownPreview(text: val.text),
              );

              if (!_splitView) return editor;

              if (constraints.maxWidth < 700) {
                return Column(children: [
                  Expanded(child: editor),
                  const _HairLine(),
                  Expanded(child: preview),
                ]);
              }

              return _ResizableSplit(
                ratio: _splitRatio,
                onRatioChanged: (r) => setState(() => _splitRatio = r),
                left: editor,
                right: preview,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Resizable Split ────────────────────────────────────────────────────────────
class _ResizableSplit extends StatefulWidget {
  const _ResizableSplit({
    required this.ratio,
    required this.onRatioChanged,
    required this.left,
    required this.right,
  });
  final double ratio;
  final ValueChanged<double> onRatioChanged;
  final Widget left;
  final Widget right;

  @override
  State<_ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends State<_ResizableSplit> {
  bool _hovering = false;
  bool _dragging = false;

  static const _handleWidth = 12.0;
  static const _minRatio = 0.2;
  static const _maxRatio = 0.8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final totalW = constraints.maxWidth;
      final leftW = (totalW - _handleWidth) * widget.ratio;
      final rightW = totalW - _handleWidth - leftW;

      return Row(
        children: [
          SizedBox(width: leftW, child: widget.left),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => setState(() => _dragging = true),
              onHorizontalDragEnd: (_) => setState(() => _dragging = false),
              onHorizontalDragUpdate: (details) {
                final newRatio = (leftW + details.delta.dx) / (totalW - _handleWidth);
                widget.onRatioChanged(newRatio.clamp(_minRatio, _maxRatio));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _handleWidth,
                decoration: BoxDecoration(
                  color: _dragging
                      ? _gold.withAlpha(18)
                      : _hovering
                          ? _border.withAlpha(180)
                          : Colors.transparent,
                  border: Border.symmetric(
                    vertical: BorderSide(
                      color: _dragging
                          ? _gold.withAlpha(180)
                          : _hovering
                              ? _borderBright
                              : _border,
                    ),
                  ),
                ),
                child: Center(
                  child: AnimatedOpacity(
                    opacity: (_hovering || _dragging) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (_) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: _dragging ? _gold : _inkMid,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: rightW, child: widget.right),
        ],
      );
    });
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────
class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.splitView,
    required this.onSplitChanged,
    required this.onSave,
    required this.onClear,
  });
  final bool splitView;
  final ValueChanged<bool> onSplitChanged;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const _PaneLabel(label: 'EDITOR', icon: Icons.edit_outlined),
          if (splitView) ...[
            const SizedBox(width: 32),
            const _PaneLabel(label: 'PREVIEW', icon: Icons.auto_stories_outlined),
          ],
          const Spacer(),
          _ToolbarChip(
            label: splitView ? 'Hide Preview' : 'Show Preview',
            icon: splitView ? Icons.vertical_split_outlined : Icons.fullscreen_outlined,
            onTap: () => onSplitChanged(!splitView),
          ),
          const SizedBox(width: 8),
          _ToolbarChip(
            label: 'Save .md',
            icon: Icons.save_alt_outlined,
            accent: true,
            onTap: onSave,
          ),
          const SizedBox(width: 8),
          _IconBtn(icon: Icons.delete_outline, tooltip: 'Clear', onTap: onClear, danger: true),
        ],
      ),
    );
  }
}

class _PaneLabel extends StatelessWidget {
  const _PaneLabel({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _inkDim),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: _inkDim,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: accent ? _gold.withAlpha(22) : _surfaceHigh,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: accent ? _goldDim : _border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: accent ? _gold : _inkMid),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: accent ? _gold : _inkMid,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap, this.danger = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, size: 15, color: danger ? _red.withAlpha(180) : _inkMid),
        ),
      ),
    );
  }
}

// ── Markdown Editor ────────────────────────────────────────────────────────────
class _MarkdownEditor extends StatelessWidget {
  const _MarkdownEditor({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        expands: true,
        cursorColor: _gold,
        cursorWidth: 1.5,
        style: GoogleFonts.jetBrainsMono(
          color: _ink,
          fontSize: 13.5,
          height: 1.65,
          letterSpacing: 0.1,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Start writing Markdown…',
          hintStyle: GoogleFonts.jetBrainsMono(color: _inkDim, fontSize: 13.5),
        ),
      ),
    );
  }
}

// ── Markdown Preview ───────────────────────────────────────────────────────────
class _MarkdownPreview extends StatefulWidget {
  const _MarkdownPreview({required this.text});
  final String text;

  @override
  State<_MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<_MarkdownPreview> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  MarkdownStyleSheet _buildSheet() {
    return MarkdownStyleSheet(
      p: GoogleFonts.lora(color: _ink, fontSize: 15, height: 1.75),
      h1: GoogleFonts.playfairDisplay(color: _ink, fontSize: 28, fontWeight: FontWeight.w700, height: 1.3),
      h2: GoogleFonts.playfairDisplay(color: _ink, fontSize: 22, fontWeight: FontWeight.w600, height: 1.35),
      h3: GoogleFonts.playfairDisplay(color: _inkMid, fontSize: 18, fontWeight: FontWeight.w600),
      h4: GoogleFonts.dmSans(color: _inkMid, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      code: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: _gold, backgroundColor: _surfaceHigh),
      codeblockDecoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      blockquoteDecoration: BoxDecoration(
        border: const Border(left: BorderSide(color: _goldDim, width: 3)),
        color: _gold.withAlpha(10),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      blockquote: GoogleFonts.lora(color: _inkMid, fontSize: 14.5, fontStyle: FontStyle.italic, height: 1.6),
      strong: GoogleFonts.lora(color: _ink, fontWeight: FontWeight.w700, fontSize: 15),
      em: GoogleFonts.lora(color: _ink, fontStyle: FontStyle.italic, fontSize: 15),
      listBullet: GoogleFonts.lora(color: _gold, fontSize: 15),
      tableHead: GoogleFonts.dmSans(color: _inkMid, fontWeight: FontWeight.w600, fontSize: 13),
      tableBody: GoogleFonts.lora(color: _ink, fontSize: 14),
      tableHeadAlign: TextAlign.left,
      tableBorder: TableBorder.all(color: _border, width: 1),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      horizontalRuleDecoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
      a: GoogleFonts.lora(color: _gold, fontSize: 15, decoration: TextDecoration.underline, decorationColor: _goldDim),
    );
  }

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(widget.text.isEmpty ? '*Nothing to preview yet.*' : widget.text);
    final sheet = _buildSheet();

    return Container(
      color: _surface,
      child: Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final seg in segments)
                if (seg is _TextSegment)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: MarkdownBody(
                      data: seg.text,
                      selectable: true,
                      styleSheet: sheet,
                    ),
                  )
                else if (seg is _MermaidSegment)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: MermaidDiagram(code: seg.code),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mermaid Diagram ────────────────────────────────────────────────────────────
sealed class _DiagramState { const _DiagramState(); }
class _DiagramLoading extends _DiagramState { const _DiagramLoading(); }
class _DiagramDone extends _DiagramState {
  const _DiagramDone(this.bytes);
  final List<int> bytes;
}
class _DiagramError extends _DiagramState {
  const _DiagramError(this.message);
  final String message;
}

class MermaidDiagram extends StatefulWidget {
  const MermaidDiagram({super.key, required this.code});
  final String code;

  @override
  State<MermaidDiagram> createState() => _MermaidDiagramState();
}

class _MermaidDiagramState extends State<MermaidDiagram> {
  _DiagramState _state = const _DiagramLoading();
  Timer? _debounce;
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    _fetch(widget.code);
  }

  @override
  void didUpdateWidget(MermaidDiagram old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 800),
        () => _fetch(widget.code),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch(String code) async {
    if (_lastCode == code) return;
    _lastCode = code;
    if (mounted) setState(() => _state = const _DiagramLoading());
    try {
      // JSON format: mermaid.ink reads theme from the "mermaid" config block.
      // Use dark theme with a background that matches the app surface.
      final payload = jsonEncode({
        'code': code,
        'mermaid': {'theme': 'dark'},
      });
      final encoded = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
      final response = await http
          .get(Uri.parse('https://mermaid.ink/img/$encoded?bgColor=1E1E26'))
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => _state = _DiagramDone(response.bodyBytes));
      } else {
        setState(() => _state = _DiagramError('HTTP ${response.statusCode}'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _DiagramError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_tree_outlined, size: 13, color: _goldDim),
                const SizedBox(width: 7),
                Text(
                  'MERMAID',
                  style: GoogleFonts.jetBrainsMono(
                    color: _goldDim, fontSize: 10,
                    letterSpacing: 1.5, fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_state is _DiagramLoading)
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: _goldDim),
                  ),
              ],
            ),
          ),
          switch (_state) {
            _DiagramLoading() => const SizedBox(
                height: 120,
                child: Center(
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _goldDim),
                  ),
                ),
              ),
            _DiagramDone(:final bytes) => Padding(
                padding: const EdgeInsets.all(16),
                child: Image.memory(
                  Uint8List.fromList(bytes),
                  fit: BoxFit.contain,
                ),
              ),
            _DiagramError(:final message) => Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C1A1A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF5C2A2A)),
                  ),
                  child: Text(
                    'Diagram error:\n$message',
                    style: GoogleFonts.jetBrainsMono(color: _red, fontSize: 12),
                  ),
                ),
              ),
          },
        ],
      ),
    );
  }
}

class _HairLine extends StatelessWidget {
  const _HairLine();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: _border);
}

// ── Paste → Markdown Page ──────────────────────────────────────────────────────
class PasteToMarkdownPage extends StatefulWidget {
  const PasteToMarkdownPage({super.key});
  @override
  State<PasteToMarkdownPage> createState() => _PasteToMarkdownPageState();
}

class _PasteToMarkdownPageState extends State<PasteToMarkdownPage> {
  final TextEditingController _outputController = TextEditingController();
  String _status = 'Paste rich text or HTML from your clipboard to convert it to Markdown.';
  String _sourceLabel = '—';
  bool _isBusy = false;

  @override
  void dispose() {
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    setState(() => _isBusy = true);
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      setState(() {
        _status = 'Clipboard not available on this platform.';
        _sourceLabel = 'N/A';
        _isBusy = false;
      });
      return;
    }

    final reader = await clipboard.read();
    String? markdown;
    String source = 'plain text';

    if (reader.canProvide(Formats.htmlText)) {
      final html = await reader.readValue(Formats.htmlText);
      if (html != null && html.toString().trim().isNotEmpty) {
        markdown = html2md.convert(html.toString());
        source = 'HTML';
      }
    }
    if (markdown == null && reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.toString().trim().isNotEmpty) {
        markdown = text.toString();
        source = 'plain text';
      }
    }

    setState(() {
      _outputController.text = markdown ?? '';
      _sourceLabel = markdown == null ? '—' : source;
      _status = markdown == null
          ? 'No supported content found on the clipboard.'
          : 'Converted from $source  ·  ${markdown.split('\n').length} lines';
      _isBusy = false;
    });
  }

  Future<void> _copy() async {
    final text = _outputController.text.trim();
    if (text.isEmpty) {
      setState(() => _status = 'Nothing to copy yet.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _status = 'Copied to clipboard.');
  }

  void _clear() => setState(() {
        _outputController.clear();
        _status = 'Paste rich text or HTML from your clipboard to convert it to Markdown.';
        _sourceLabel = '—';
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 48,
          color: _surface,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const _PaneLabel(label: 'RTF → MARKDOWN CONVERTER', icon: Icons.transform_outlined),
              const Spacer(),
              _ToolbarChip(
                label: 'Paste Clipboard',
                icon: Icons.content_paste_outlined,
                accent: true,
                onTap: _isBusy ? () {} : _paste,
              ),
              const SizedBox(width: 8),
              _ToolbarChip(
                label: 'Copy Markdown',
                icon: Icons.copy_outlined,
                onTap: _isBusy ? () {} : _copy,
              ),
              const SizedBox(width: 8),
              _IconBtn(icon: Icons.delete_outline, tooltip: 'Clear', onTap: _clear, danger: true),
            ],
          ),
        ),
        const _HairLine(),
        Container(
          height: 34,
          color: _surfaceHigh,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _sourceLabel == '—' ? _inkDim : _gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('Source: $_sourceLabel',
                  style: GoogleFonts.jetBrainsMono(color: _inkDim, fontSize: 11)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(_status,
                    style: GoogleFonts.dmSans(color: _inkMid, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              if (_isBusy) ...[
                const SizedBox(width: 8),
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: _gold)),
              ],
            ],
          ),
        ),
        const _HairLine(),
        Expanded(
          child: Container(
            color: _bg,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _outputController,
              readOnly: true,
              expands: true,
              maxLines: null,
              style: GoogleFonts.jetBrainsMono(color: _ink, fontSize: 13.5, height: 1.65),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Markdown output will appear here…',
                hintStyle: GoogleFonts.jetBrainsMono(color: _inkDim, fontSize: 13.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
