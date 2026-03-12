import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../providers/app_providers.dart';
import '../services/notification_service.dart';
import 'add_note_item_screen.dart';
import 'note_file_editor_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  /// If set, the screen opens directly inside the given folder.
  final String? openFolderId;

  /// If set, the screen opens directly in the file editor.
  final String? openFileId;

  const NotesScreen({super.key, this.openFolderId, this.openFileId});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  // Navigation stack: list of (folderId, folderTitle) pairs
  // null folderId = root
  final List<({String? id, String title})> _navStack = [
    (id: null, title: 'Notes'),
  ];

  String? get _currentFolderId => _navStack.last.id;

  @override
  void initState() {
    super.initState();
    // Deep-link: open folder from notification
    if (widget.openFolderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFolderById(widget.openFolderId!);
      });
    }
    // Deep-link: open file from notification
    if (widget.openFileId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFileById(widget.openFileId!);
      });
    }
  }

  void _openFolderById(String id) {
    final notesState = ref.read(noteProvider);
    final folder = notesState.folders.where((f) => f.id == id).firstOrNull;
    if (folder == null) return;
    setState(() {
      _navStack.add((id: folder.id, title: folder.title));
    });
    _markFolderVisited(folder);
  }

  void _openFileById(String id) {
    final notesState = ref.read(noteProvider);
    final file = notesState.files.where((f) => f.id == id).firstOrNull;
    if (file == null) return;
    _openFile(file);
  }

  void _navigateIntoFolder(NoteFolder folder) {
    setState(() {
      _navStack.add((id: folder.id, title: folder.title));
    });
    _markFolderVisited(folder);
  }

  void _navigateBack() {
    if (_navStack.length > 1) setState(() => _navStack.removeLast());
  }

  void _markFolderVisited(NoteFolder folder) async {
    await ref.read(noteProvider.notifier).markFolderVisited(folder.id);
    // Reschedule next reminder if repeat
    if (folder.reminder != null && folder.reminder!.isEnabled) {
      await NotificationService.cancelNoteReminder(folder.id);
      final now = DateTime.now();
      final next = folder.reminder!.computeNextReminder(now);
      if (next != null) {
        await NotificationService.scheduleNoteReminder(
          id: folder.id,
          title: '📁 Revisit: ${folder.title}',
          body: 'Time to review this folder',
          scheduledTime: next,
          payload: 'note_folder_${folder.id}',
        );
      }
    }
  }

  void _markFileVisited(NoteFile file) async {
    await ref.read(noteProvider.notifier).markFileVisited(file.id);
    if (file.reminder != null && file.reminder!.isEnabled) {
      await NotificationService.cancelNoteReminder(file.id);
      final now = DateTime.now();
      final next = file.reminder!.computeNextReminder(now);
      if (next != null) {
        await NotificationService.scheduleNoteReminder(
          id: file.id,
          title: '📄 Revisit: ${file.title}',
          body: 'Time to review this note',
          scheduledTime: next,
          payload: 'note_file_${file.id}',
        );
      }
    }
  }

  void _openFile(NoteFile file) async {
    _markFileVisited(file);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteFileEditorScreen(fileId: file.id),
      ),
    );
  }

  Future<void> _scheduleReminder({
    required String id,
    required String title,
    required NoteReminder reminder,
    required bool isFolder,
    DateTime? lastVisited,
  }) async {
    await NotificationService.cancelNoteReminder(id);
    if (!reminder.isEnabled) return;
    final next = reminder.computeNextReminder(lastVisited);
    if (next == null) return;
    await NotificationService.scheduleNoteReminder(
      id: id,
      title: isFolder ? '📁 Revisit: $title' : '📄 Revisit: $title',
      body: 'Time to review this ${isFolder ? 'folder' : 'note'}',
      scheduledTime: next,
      payload: isFolder ? 'note_folder_$id' : 'note_file_$id',
    );
  }

  Future<void> _deleteFolder(BuildContext ctx, NoteFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
            'Delete "${folder.title}" and all its contents? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await NotificationService.cancelNoteReminder(folder.id);
    await ref.read(noteProvider.notifier).deleteFolder(folder.id);
  }

  Future<void> _deleteFile(BuildContext ctx, NoteFile file) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Delete "${file.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await NotificationService.cancelNoteReminder(file.id);
    await ref.read(noteProvider.notifier).deleteFile(file.id);
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(noteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final folders = notesState.folders
        .where((f) => f.parentFolderId == _currentFolderId)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    final files = notesState.files
        .where((f) => f.folderId == _currentFolderId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final isEmpty = folders.isEmpty && files.isEmpty;

    return PopScope(
      canPop: _navStack.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _navStack.length > 1) _navigateBack();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5FF),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          elevation: 0,
          leading: _navStack.length > 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: _navigateBack,
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _navStack.last.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (_navStack.length > 1)
                Text(
                  _navStack.map((n) => n.title).join(' › '),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.push<NoteFolder>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddNoteItemScreen(
                      isFolder: true,
                      defaultParentId: _currentFolderId,
                    ),
                  ),
                );
                if (result != null) {
                  await ref.read(noteProvider.notifier).addFolder(result);
                  if (result.reminder != null) {
                    await _scheduleReminder(
                      id: result.id,
                      title: result.title,
                      reminder: result.reminder!,
                      isFolder: true,
                    );
                  }
                }
              },
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('Folder'),
            ),
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.push<NoteFile>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddNoteItemScreen(
                      isFolder: false,
                      defaultParentId: _currentFolderId,
                    ),
                  ),
                );
                if (result != null) {
                  await ref.read(noteProvider.notifier).addFile(result);
                  if (result.reminder != null) {
                    await _scheduleReminder(
                      id: result.id,
                      title: result.title,
                      reminder: result.reminder!,
                      isFolder: false,
                    );
                  }
                  // Open editor immediately
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NoteFileEditorScreen(fileId: result.id),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.note_add_outlined, size: 18),
              label: const Text('Note'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: isEmpty
            ? _buildEmptyState(context, isDark)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (folders.isNotEmpty) ...[
                    _sectionHeader(context, 'Folders (${folders.length})'),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: folders.length,
                      itemBuilder: (context, index) => _FolderCard(
                        folder: folders[index],
                        isDark: isDark,
                        primary: primary,
                        onTap: () => _navigateIntoFolder(folders[index]),
                        onEdit: () async {
                          final f = folders[index];
                          final updated = await Navigator.push<NoteFolder>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddNoteItemScreen(
                                isFolder: true,
                                editFolder: f,
                                defaultParentId: _currentFolderId,
                              ),
                            ),
                          );
                          if (updated != null) {
                            await ref
                                .read(noteProvider.notifier)
                                .updateFolder(updated);
                            await _scheduleReminder(
                              id: updated.id,
                              title: updated.title,
                              reminder: updated.reminder ??
                                  const NoteReminder(
                                    type: NoteReminderType.intervalDays,
                                    isEnabled: false,
                                  ),
                              isFolder: true,
                              lastVisited: updated.lastVisitedAt,
                            );
                          }
                        },
                        onDelete: () => _deleteFolder(context, folders[index]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (files.isNotEmpty) ...[
                    _sectionHeader(context, 'Notes (${files.length})'),
                    const SizedBox(height: 8),
                    ...files.map(
                      (file) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FileCard(
                          file: file,
                          isDark: isDark,
                          primary: primary,
                          onTap: () => _openFile(file),
                          onEdit: () async {
                            final updated = await Navigator.push<NoteFile>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddNoteItemScreen(
                                  isFolder: false,
                                  editFile: file,
                                  defaultParentId: _currentFolderId,
                                ),
                              ),
                            );
                            if (updated != null) {
                              await ref
                                  .read(noteProvider.notifier)
                                  .updateFile(updated);
                              await _scheduleReminder(
                                id: updated.id,
                                title: updated.title,
                                reminder: updated.reminder ??
                                    const NoteReminder(
                                      type: NoteReminderType.intervalDays,
                                      isEnabled: false,
                                    ),
                                isFolder: false,
                                lastVisited: updated.lastVisitedAt,
                              );
                            }
                          },
                          onDelete: () => _deleteFile(context, file),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 72,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 16),
          Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Folder" or "Note" above to get started',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Folder Card
// ─────────────────────────────────────────────────────────────────────────────
class _FolderCard extends StatelessWidget {
  final NoteFolder folder;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FolderCard({
    required this.folder,
    required this.isDark,
    required this.primary,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = folder.isReminderOverdue;
    final cardColor = isDark ? const Color(0xFF23233A) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? Colors.red : folder.color.withValues(alpha: 0.4),
          width: isOverdue ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isOverdue ? Colors.red : folder.color).withValues(alpha: 0.15),
            blurRadius: isOverdue ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: folder.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.folder_rounded,
                        color: folder.color,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (isOverdue)
                      const Icon(Icons.alarm_rounded,
                          color: Colors.red, size: 16),
                    _ContextMenuButton(onEdit: onEdit, onDelete: onDelete),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    folder.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOverdue)
                  Text(
                    'Review overdue',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File Card
// ─────────────────────────────────────────────────────────────────────────────
class _FileCard extends StatelessWidget {
  final NoteFile file;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FileCard({
    required this.file,
    required this.isDark,
    required this.primary,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = file.isReminderOverdue;
    final cardColor = isDark ? const Color(0xFF23233A) : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? Colors.red : file.color.withValues(alpha: 0.4),
          width: isOverdue ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isOverdue ? Colors.red : file.color).withValues(alpha: 0.12),
            blurRadius: isOverdue ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: file.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: file.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              file.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOverdue)
                            const Icon(Icons.alarm_rounded,
                                color: Colors.red, size: 15),
                        ],
                      ),
                      if (file.preview.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          file.preview,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (isOverdue) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Review overdue',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _ContextMenuButton(onEdit: onEdit, onDelete: onDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared 3-dot context menu
// ─────────────────────────────────────────────────────────────────────────────
class _ContextMenuButton extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContextMenuButton({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
