import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html2md/html2md.dart' as html2md;
import 'package:super_clipboard/super_clipboard.dart';

void main() {
  runApp(const MarkDApp());
}

class MarkDApp extends StatelessWidget {
  const MarkDApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B5E5A),
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme().copyWith(
        bodyMedium: const TextStyle(fontSize: 15),
      ),
    );

    return MaterialApp(
      title: 'MarkD',
      theme: theme,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(
            title: const Text('MarkD'),
            centerTitle: false,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F3D3E),
                    Color(0xFF2F4858),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
          ),
          body: Row(
            children: [
              if (useRail)
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() {
                      _index = value;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: const Color(0xFFF3F1EC),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.edit_note),
                      label: Text('Editor'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.paste),
                      label: Text('RTFtoMD'),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: const [
                    EditorPage(),
                    PasteToMarkdownPage(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() {
                      _index = value;
                    });
                  },
                  backgroundColor: const Color(0xFFF3F1EC),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.edit_note),
                      label: 'Editor',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.paste),
                      label: 'RTFtoMD',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _controller = TextEditingController(
    text: '# Welcome to MarkD\n'
        '\n'
        'Type Markdown on the left and preview it on the right.\n'
        '\n'
        '## Quick examples\n'
        '- **Bold** and _italic_\n'
        '- Inline `code`\n'
        '- [Links](https://flutter.dev)\n'
        '\n'
        '> Blockquote\n'
        '\n'
        '```dart\n'
        'void main() => print(\'Hello MarkD\');\n'
        '```\n',
  );
  bool _splitView = true;

  Future<void> _saveMarkdown() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save yet.')),
      );
      return;
    }

    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Markdown',
          extensions: ['md'],
        ),
      ],
      suggestedName: 'markd.md',
    );
    final path = location?.path;
    if (path == null) {
      return;
    }

    final targetPath =
        path.toLowerCase().endsWith('.md') ? path : '$path.md';
    final normalizedPath = targetPath.replaceAll('\\', '/');
    final fileName = normalizedPath.split('/').last;
    final fileData = Uint8List.fromList(text.codeUnits);
    final mdFile = XFile.fromData(
      fileData,
      mimeType: 'text/markdown',
      name: fileName,
    );
    await mdFile.saveTo(targetPath);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $targetPath')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF6F3EE),
            Color(0xFFE7EFEF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _EditorToolbar(
            splitView: _splitView,
            onSplitChanged: (value) {
              setState(() {
                _splitView = value;
              });
            },
            onSave: _saveMarkdown,
            onClear: () {
              _controller.clear();
              setState(() {});
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final editor = _MarkdownEditor(controller: _controller);
                final preview = ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    return _MarkdownPreview(text: value.text);
                  },
                );

                if (!_splitView) {
                  return editor;
                }

                if (constraints.maxWidth >= 900) {
                  return Row(
                    children: [
                      Expanded(child: editor),
                      const VerticalDivider(width: 1),
                      Expanded(child: preview),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(child: editor),
                    const Divider(height: 1),
                    Expanded(child: preview),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Markdown Editor',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Row(
            children: [
              const Text('Split preview'),
              const SizedBox(width: 8),
              Switch(
                value: splitView,
                onChanged: onSplitChanged,
              ),
            ],
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save .md'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _MarkdownEditor extends StatelessWidget {
  const _MarkdownEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            expands: true,
            style: GoogleFonts.sourceCodePro(
              fontSize: 14,
              height: 1.45,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Write Markdown here...',
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Markdown(
            data: text.isEmpty ? '_Nothing to preview yet._' : text,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}

class PasteToMarkdownPage extends StatefulWidget {
  const PasteToMarkdownPage({super.key});

  @override
  State<PasteToMarkdownPage> createState() => _PasteToMarkdownPageState();
}

class _PasteToMarkdownPageState extends State<PasteToMarkdownPage> {
  final TextEditingController _outputController = TextEditingController();
  String _status = 'Paste RTF or HTML from your clipboard to convert it.';
  String _sourceLabel = 'None';
  bool _isBusy = false;

  @override
  void dispose() {
    _outputController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    setState(() {
      _isBusy = true;
    });

    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      setState(() {
        _status = 'Clipboard access is not available on this platform.';
        _sourceLabel = 'Unavailable';
        _isBusy = false;
      });
      return;
    }

    final reader = await clipboard.read();
    String? markdown;
    String source = 'Plain text';

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
        source = 'Plain text';
      }
    }

    setState(() {
      _outputController.text = markdown ?? '';
      _status = markdown == null
          ? 'No supported rich text found on the clipboard.'
          : 'Converted from $source.';
      _sourceLabel = markdown == null ? 'None' : source;
      _isBusy = false;
    });
  }

  Future<void> _copyMarkdown() async {
    if (_outputController.text.trim().isEmpty) {
      setState(() {
        _status = 'Nothing to copy yet.';
      });
      return;
    }

    await Clipboard.setData(ClipboardData(text: _outputController.text));
    setState(() {
      _status = 'Markdown copied to clipboard.';
    });
  }

  void _clear() {
    setState(() {
      _outputController.clear();
      _status = 'Paste RTF or HTML from your clipboard to convert it.';
      _sourceLabel = 'None';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF6F3EE),
            Color(0xFFE7EFEF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'RTFtoMD',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _pasteFromClipboard,
                  icon: const Icon(Icons.paste),
                  label: const Text('Paste RTF/HTML'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _copyMarkdown,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Markdown'),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _isBusy ? null : _clear,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Source: $_sourceLabel',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colorScheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TextField(
                          controller: _outputController,
                          readOnly: true,
                          expands: true,
                          maxLines: null,
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 14,
                            height: 1.45,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Markdown output will appear here...',
                          ),
                        ),
                      ),
                    ],
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
