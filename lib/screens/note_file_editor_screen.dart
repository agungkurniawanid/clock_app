import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../providers/app_providers.dart';

class NoteFileEditorScreen extends ConsumerStatefulWidget {
  final String fileId;

  const NoteFileEditorScreen({super.key, required this.fileId});

  @override
  ConsumerState<NoteFileEditorScreen> createState() =>
      _NoteFileEditorScreenState();
}

class _NoteFileEditorScreenState extends ConsumerState<NoteFileEditorScreen> {
  late TextEditingController _contentCtrl;
  Timer? _saveDebounce;
  bool _isDirty = false;
  NoteFile? _file;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final notesState = ref.read(noteProvider);
    final file =
        notesState.files.where((f) => f.id == widget.fileId).firstOrNull;
    if (file == null) return;
    setState(() {
      _file = file;
      _contentCtrl.text = file.content;
      // Move cursor to end
      _contentCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _contentCtrl.text.length),
      );
    });
  }

  void _onContentChanged(String value) {
    _isDirty = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    if (!_isDirty || _file == null) return;
    final updated = _file!.copyWith(
      content: _contentCtrl.text,
      updatedAt: DateTime.now(),
    );
    await ref.read(noteProvider.notifier).updateFile(updated);
    setState(() {
      _file = updated;
      _isDirty = false;
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // Synchronous save on dispose is not possible with async, but we trigger it
    if (_isDirty && _file != null) {
      final updated = _file!.copyWith(
        content: _contentCtrl.text,
        updatedAt: DateTime.now(),
      );
      ref.read(noteProvider.notifier).updateFile(updated);
    }
    _contentCtrl.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch changes from provider (e.g., reminder toggled from another screen)
    final notesState = ref.watch(noteProvider);
    final file =
        notesState.files.where((f) => f.id == widget.fileId).firstOrNull;

    if (file == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: const Center(child: Text('Note not found')),
      );
    }

    final isOverdue = file.isReminderOverdue;

    return PopScope(
      onPopInvokedWithResult: (_, __) async {
        _saveDebounce?.cancel();
        await _save();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F0F1A) : const Color(0xFFFAFAFF),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                _isDirty
                    ? 'Unsaved changes...'
                    : 'Updated ${_formatDateTime(file.updatedAt)}',
                style: TextStyle(
                  fontSize: 11,
                  color: _isDirty
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          actions: [
            if (isOverdue)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Tooltip(
                  message: 'Review reminder overdue',
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm_rounded, color: Colors.red, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Overdue',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(
                _isDirty ? Icons.save_rounded : Icons.check_circle_outline,
                color: _isDirty
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
              ),
              onPressed: _isDirty ? _save : null,
              tooltip: 'Save',
            ),
          ],
        ),
        body: Column(
          children: [
            // Word / char count bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              child: Text(
                '${_wordCount(_contentCtrl.text)} words · '
                '${_contentCtrl.text.length} chars',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.35),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Start writing your note...',
                    hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.25),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onContentChanged,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _wordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}
