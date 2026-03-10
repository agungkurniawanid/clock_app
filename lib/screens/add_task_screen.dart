import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/task_model.dart';
import '../providers/app_providers.dart';
import '../data/dummy_data.dart';
import '../theme/app_colors.dart';
import '../services/audio_service.dart';
import '../utils/app_toast.dart';
import 'login_screen.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class AddTaskScreen extends ConsumerStatefulWidget {
  final TaskModel? editTask;

  const AddTaskScreen({super.key, this.editTask});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Custom repeat local state
  int _customInterval = 1;
  String _customIntervalUnit = 'Days'; // Days, Weeks, Months, Years
  String _customEndType = 'Never'; // Never, On Date, After
  DateTime? _customEndDate;
  int _customEndAfterCount = 1;
  final List<bool> _customWeekDays = List.filled(7, false);

  // ── Checklist & Sub-task local state ──────────────────────────────────────
  List<ChecklistItem> _checklist = [];
  List<SubTask> _subTasks = [];
  final Map<String, TextEditingController> _controllers = {};
  bool _autoCompleteOnChecklist = false;

  // ── Get or create a TextEditingController keyed by item ID ────────────────
  TextEditingController _ctrl(String id, [String initial = '']) =>
      _controllers.putIfAbsent(id, () => TextEditingController(text: initial));

  // ── Unique ID generator ───────────────────────────────────────────────────
  String _uid() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    if (widget.editTask != null) {
      final t = widget.editTask!;
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description;
      _checklist = List.from(t.checklist);
      _subTasks = List.from(t.subTasks);
      _autoCompleteOnChecklist = t.autoCompleteOnChecklist;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final n = ref.read(addTaskFormProvider.notifier);
        n.setTitle(t.title);
        n.setDescription(t.description);
        n.setCategory(t.category);
        n.setDate(t.date);
        n.setTime(t.time);
        n.setAlarmMode(t.alarmMode);
        n.setMusicFile(t.musicFile);
        n.setVolume(t.volume.toDouble());
        n.setSnooze(t.snoozeMinutes);
        n.setRepeat(t.repeat);
        if (t.repeat == RepeatType.custom) {
          _customInterval = t.customInterval;
          _customIntervalUnit = t.customIntervalUnit;
          _customEndType = t.customEndType;
          _customEndDate = t.customEndDate;
          _customEndAfterCount = t.customEndAfterCount;
          for (int i = 0; i < 7; i++) {
            _customWeekDays[i] = t.customWeekDays[i];
          }
        }
        n.setPriority(t.priority);
        n.setColorTag(t.colorTag);
        n.setStatus(t.status);
        // Due date fields
        n.toggleDueDate(t.dueDateEnabled);
        if (t.dueDate != null) n.setDueDate(t.dueDate!);
        if (t.dueTime != null) n.setDueTime(t.dueTime!);
        n.toggleDueReminder(t.dueReminderEnabled);
        for (final r in t.dueReminders) {
          n.addDueReminder(r);
        }
        n.setDueAlarmMode(t.dueAlarmMode);
        n.setDueMusicFile(t.dueMusicFile);
        n.setDueVolume(t.dueVolume.toDouble());
        n.setDueSnooze(t.dueSnoozeMinutes);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(addTaskFormProvider.notifier).reset();
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(addTaskFormProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? darkCard : lightCard;
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.editTask != null ? 'Edit Schedule' : 'Add New Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Local storage badge (visible only when not logged in) ─────────
          if (!isLoggedIn && widget.editTask == null) ...[
            _buildLocalStorageBanner(context, isDark),
            const SizedBox(height: 16),
          ],
          _section(
              context, '① Basic Info', _buildBasicInfo(context, form, card)),
          const SizedBox(height: 16),
          _section(context, '② Start Date & Alarm',
              _buildStartDateAlarm(context, form, card)),
          const SizedBox(height: 16),
          _section(context, '③ Due Date & Reminders',
              _buildDueDateReminders(context, form, card)),
          const SizedBox(height: 16),
          _section(context, '④ Repeat', _buildRepeat(context, form, card)),
          const SizedBox(height: 16),
          _section(context, '⑤ Priority & Color Tag',
              _buildPriorityColor(context, form, card)),
          const SizedBox(height: 16),
          _section(context, '⑥ Checklist & Sub-tasks',
              _buildChecklistSubtasks(context, isDark, card)),
          const SizedBox(height: 16),
          if (widget.editTask != null) ...[
            _section(
                context, '⑦ Status', _buildStatusSelector(context, form, card)),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Schedule'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickMusicFile(void Function(String?) setter) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path; // full device path
      if (path != null) {
        setter(path);
        // Persist the custom file path so it appears in future music pickers
        await ref.read(customMusicFilesProvider.notifier).addFile(path);
      }
    }
  }

  /// Bottom sheet listing built-in alarm sounds, previously used custom files,
  /// and an option to browse for a new file from device storage.
  Future<void> _showMusicPickerSheet(
      BuildContext context, void Function(String?) setter) async {
    String? previewingFile;

    // Collect custom files: from dedicated persistent list + any in saved tasks
    final persistedCustomFiles = ref.read(customMusicFilesProvider);
    final tasks = ref.read(taskListProvider);
    final seen = <String>{};
    final customFiles = <String>[];
    // First add from the dedicated custom musik list
    for (final f in persistedCustomFiles) {
      if (!AudioService.isAsset(f) && seen.add(f)) {
        customFiles.add(f);
      }
    }
    // Then add any from saved tasks that are not yet in the dedicated list
    for (final t in tasks) {
      for (final f in [t.musicFile, t.dueMusicFile]) {
        if (f != null && !AudioService.isAsset(f) && seen.add(f)) {
          customFiles.add(f);
        }
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.music_note_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Select Alarm Sound',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Divider(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    // ── Previously uploaded / custom sounds ───────────────
                    if (customFiles.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Custom / Uploaded',
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                                color: Theme.of(ctx).colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      ...customFiles.map((path) {
                        final name = AudioService.displayName(path);
                        final isPreviewing = previewingFile == path;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(ctx)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.12),
                            child: Icon(Icons.folder_rounded,
                                size: 16,
                                color: Theme.of(ctx).colorScheme.secondary),
                          ),
                          title: Text(
                            name
                                .replaceAll('_', ' ')
                                .replaceAll('.mp3', '')
                                .replaceAll('.m4a', '')
                                .replaceAll('.ogg', '')
                                .replaceAll('.wav', ''),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Custom upload'),
                          trailing: IconButton(
                            icon: Icon(
                              isPreviewing
                                  ? Icons.stop_circle_rounded
                                  : Icons.play_circle_rounded,
                              color: Theme.of(ctx).colorScheme.secondary,
                            ),
                            onPressed: () {
                              if (isPreviewing) {
                                AudioService.instance.stop();
                                setS(() => previewingFile = null);
                              } else {
                                AudioService.instance
                                    .previewAsset(path, volume: 0.8);
                                setS(() => previewingFile = path);
                              }
                            },
                          ),
                          onTap: () {
                            AudioService.instance.stop();
                            setter(path);
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                      const Divider(height: 16),
                    ],

                    // ── Default alarm sounds ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(
                        'Default Alarm Sounds',
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    ...AudioService.defaultSounds.map((f) {
                      final isPreviewing = previewingFile == f;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(ctx)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          child: Icon(Icons.music_note_rounded,
                              size: 16,
                              color: Theme.of(ctx).colorScheme.primary),
                        ),
                        title: Text(
                          f.replaceAll('_', ' ').replaceAll('.mp3', ''),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Built-in'),
                        trailing: IconButton(
                          icon: Icon(
                            isPreviewing
                                ? Icons.stop_circle_rounded
                                : Icons.play_circle_rounded,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                          onPressed: () {
                            if (isPreviewing) {
                              AudioService.instance.stop();
                              setS(() => previewingFile = null);
                            } else {
                              AudioService.instance
                                  .previewAsset(f, volume: 0.8);
                              setS(() => previewingFile = f);
                            }
                          },
                        ),
                        onTap: () {
                          AudioService.instance.stop();
                          setter(f);
                          Navigator.pop(ctx);
                        },
                      );
                    }),

                    // ── Browse files ──────────────────────────────────────
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _pickMusicFile(setter);
                        },
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Browse files from storage'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Stop any preview playing when sheet is closed
    AudioService.instance.stop();
  }

  void _save() {
    final form = ref.read(addTaskFormProvider);
    if (form.title.trim().isEmpty) {
      AppToast.show(context, 'Please enter a title', type: ToastType.error);
      return;
    }
    // Sync text controllers into data before saving
    final syncedChecklist = _syncChecklistCtrls(_checklist);
    final syncedSubTasks = _syncSubTasksCtrls(_subTasks);
    final newTask = TaskModel(
      id: widget.editTask?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: form.title,
      description: form.description,
      category: form.category,
      status: () {
        if (widget.editTask != null && form.hasStatus && form.status != null) {
          return form.status!;
        }
        final taskDay =
            DateTime(form.date.year, form.date.month, form.date.day);
        final now = DateTime.now();
        final todayDay = DateTime(now.year, now.month, now.day);
        return taskDay.isAfter(todayDay)
            ? TaskStatus.upcoming
            : TaskStatus.todo;
      }(),
      priority: form.priority,
      date: form.date,
      time: form.time,
      alarmMode: form.alarmMode,
      musicFile: form.musicFile,
      volume: form.volume.round(),
      snoozeMinutes: form.snoozeMinutes,
      dueDateEnabled: form.dueDateEnabled,
      dueDate: form.dueDate,
      dueTime: form.dueTime,
      dueReminderEnabled: form.dueReminderEnabled,
      dueReminders: form.dueReminders,
      dueAlarmMode: form.dueAlarmMode,
      dueMusicFile: form.dueMusicFile,
      dueVolume: form.dueVolume.round(),
      dueSnoozeMinutes: form.dueSnoozeMinutes,
      repeat: form.repeat,
      weekDays: form.weekDays,
      customInterval: _customInterval,
      customIntervalUnit: _customIntervalUnit,
      customEndType: _customEndType,
      customEndDate: _customEndDate,
      customEndAfterCount: _customEndAfterCount,
      customWeekDays: List.from(_customWeekDays),
      reminders: form.reminders,
      colorTag: form.colorTag,
      history: widget.editTask?.history ?? [],
      checklist: syncedChecklist,
      subTasks: syncedSubTasks,
      autoCompleteOnChecklist: _autoCompleteOnChecklist,
    );
    if (widget.editTask != null) {
      ref.read(taskListProvider.notifier).updateTask(newTask);
    } else {
      ref.read(taskListProvider.notifier).addTask(newTask);
    }
    AppToast.show(
      context,
      widget.editTask != null ? 'Schedule updated!' : 'Schedule saved!',
      type: ToastType.success,
    );
    Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local storage banner
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLocalStorageBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusTodo.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: statusTodo.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phone_android_rounded, color: statusTodo, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Task ini akan disimpan di penyimpanan lokal perangkat.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusTodo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const Text(
              'Login untuk menyimpan ke akun',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: statusTodo,
              side: const BorderSide(color: statusTodo, width: 1.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  // Checklist & Sub-task helpers
  // ─────────────────────────────────────────────────────────────────────────

  List<ChecklistItem> _syncChecklistCtrls(List<ChecklistItem> items) => items
      .map((c) {
        final t = _controllers[c.id]?.text.trim() ?? c.title;
        return c.copyWith(title: t);
      })
      .where((c) => c.title.isNotEmpty)
      .toList();

  List<SubTask> _syncSubTasksCtrls(List<SubTask> tasks) => tasks
      .map((st) {
        final t = _controllers[st.id]?.text.trim() ?? st.title;
        return SubTask(
          id: st.id,
          title: t,
          isChecked: st.isChecked,
          checklist: _syncChecklistCtrls(st.checklist),
          subTasks: _syncSubTasksCtrls(st.subTasks),
        );
      })
      .where((st) => st.title.isNotEmpty)
      .toList();

  List<SubTask> _updateSubTaskNode(
          List<SubTask> tasks, String id, SubTask Function(SubTask) fn) =>
      tasks
          .map((t) => t.id == id
              ? fn(t)
              : t.copyWith(subTasks: _updateSubTaskNode(t.subTasks, id, fn)))
          .toList();

  List<SubTask> _removeSubTaskNode(List<SubTask> tasks, String id) => tasks
      .where((t) => t.id != id)
      .map((t) => t.copyWith(subTasks: _removeSubTaskNode(t.subTasks, id)))
      .toList();

  // ─────────────────────────────────────────────────────────────────────────
  // ⑥ Checklist & Sub-tasks UI
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildChecklistSubtasks(
      BuildContext context, bool isDark, Color card) {
    final primary = Theme.of(context).colorScheme.primary;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Flat checklist ──────────────────────────────────────────────
        _clSubHeader(context, Icons.checklist_rounded, 'Checklist'),
        const SizedBox(height: 6),
        ..._checklist.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return _clItemRow(
            context,
            isDark,
            id: item.id,
            initialText: item.title,
            hint: 'Checklist item...',
            onDelete: () {
              _controllers.remove(item.id);
              setState(() => _checklist.removeAt(i));
            },
          );
        }),
        _addItemBtn(context, 'Add Checklist Item', () {
          setState(() {
            _checklist.add(ChecklistItem(id: _uid(), title: ''));
          });
        }, primary),
        const SizedBox(height: 16),

        // ── Sub-tasks ───────────────────────────────────────────────────
        _clSubHeader(context, Icons.account_tree_rounded, 'Sub-tasks'),
        const SizedBox(height: 6),
        for (final st in _subTasks)
          _buildSubTaskNode(context, isDark, st, 0, primary, textSecondary),
        _addItemBtn(context, 'Add Sub-task', () {
          setState(() {
            _subTasks.add(SubTask(id: _uid(), title: ''));
          });
        }, primary),

        // ── Auto-complete toggle ────────────────────────────────────────
        if (_checklist.isNotEmpty || _subTasks.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildAutoCompleteToggle(context, primary, textSecondary),
        ],
      ],
    );
  }

  Widget _buildSubTaskNode(
    BuildContext context,
    bool isDark,
    SubTask st,
    int depth,
    Color primary,
    Color? textSecondary,
  ) {
    final leftPad = depth * 16.0;
    final card = isDark ? darkCard : lightCard;
    return Padding(
      padding: EdgeInsets.only(left: leftPad, bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-task title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.drag_handle_rounded,
                      size: 16, color: textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _ctrl(st.id, st.title),
                      decoration: const InputDecoration(
                        hintText: 'Sub-task title...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.red.withValues(alpha: 0.7)),
                    splashRadius: 18,
                    onPressed: () {
                      _controllers.remove(st.id);
                      setState(() {
                        _subTasks = _removeSubTaskNode(_subTasks, st.id);
                      });
                    },
                  ),
                ],
              ),
            ),

            // Nested checklist
            if (st.checklist.isNotEmpty || true) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 15, color: textSecondary),
                        const SizedBox(width: 6),
                        Text('Checklist',
                            style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (int i = 0; i < st.checklist.length; i++)
                      _clItemRow(
                        context,
                        isDark,
                        id: st.checklist[i].id,
                        initialText: st.checklist[i].title,
                        hint: 'Checklist item...',
                        compact: true,
                        onDelete: () {
                          final cid = st.checklist[i].id;
                          _controllers.remove(cid);
                          setState(() {
                            _subTasks = _updateSubTaskNode(
                                _subTasks,
                                st.id,
                                (t) => t.copyWith(
                                    checklist: t.checklist
                                        .where((c) => c.id != cid)
                                        .toList()));
                          });
                        },
                      ),
                    _addItemBtn(
                      context,
                      'Add Checklist Item',
                      () {
                        final newItem = ChecklistItem(id: _uid(), title: '');
                        setState(() {
                          _subTasks = _updateSubTaskNode(
                              _subTasks,
                              st.id,
                              (t) => t.copyWith(
                                  checklist: [...t.checklist, newItem]));
                        });
                      },
                      primary,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],

            // Nested sub-tasks
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_tree_rounded,
                          size: 15, color: textSecondary),
                      const SizedBox(width: 6),
                      Text('Sub-tasks',
                          style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final child in st.subTasks)
                    _buildSubTaskNode(
                        context, isDark, child, 0, primary, textSecondary),
                  _addItemBtn(
                    context,
                    'Add Sub-task',
                    () {
                      final newSt = SubTask(id: _uid(), title: '');
                      setState(() {
                        _subTasks = _updateSubTaskNode(
                            _subTasks,
                            st.id,
                            (t) =>
                                t.copyWith(subTasks: [...t.subTasks, newSt]));
                      });
                    },
                    primary,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoCompleteToggle(
      BuildContext context, Color primary, Color? textSecondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _autoCompleteOnChecklist
            ? primary.withValues(alpha: 0.1)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _autoCompleteOnChecklist
              ? primary.withValues(alpha: 0.45)
              : (textSecondary?.withValues(alpha: 0.18) ?? Colors.grey),
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _autoCompleteOnChecklist
                  ? primary.withValues(alpha: 0.15)
                  : (textSecondary?.withValues(alpha: 0.1) ?? Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: _autoCompleteOnChecklist ? primary : textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Auto-complete when all done',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _autoCompleteOnChecklist ? primary : textPrimary,
                      ),
                    ),
                    if (_autoCompleteOnChecklist) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ENABLED',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Task will automatically become Completed\nwhen all checklist & sub-tasks are checked',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _autoCompleteOnChecklist,
            onChanged: (v) => setState(() => _autoCompleteOnChecklist = v),
            activeThumbColor: primary,
            activeTrackColor: primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _clSubHeader(BuildContext context, IconData icon, String label) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 18, color: primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
        ),
      ],
    );
  }

  Widget _clItemRow(
    BuildContext context,
    bool isDark, {
    required String id,
    required String initialText,
    required String hint,
    required VoidCallback onDelete,
    bool compact = false,
  }) {
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 6),
      child: Row(
        children: [
          Icon(Icons.radio_button_unchecked_rounded,
              size: compact ? 14 : 16, color: textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _ctrl(id, initialText),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    vertical: compact ? 6 : 8, horizontal: 0),
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: compact ? 12 : 14),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded,
                size: compact ? 14 : 16,
                color: Colors.red.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _addItemBtn(
    BuildContext context,
    String label,
    VoidCallback onTap,
    Color primary, {
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.4), width: 1.2),
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14, vertical: compact ? 7 : 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 8 : 10)),
        ),
        icon: Icon(Icons.add_rounded, size: compact ? 15 : 17),
        label: Text(
          label,
          style: TextStyle(
              fontSize: compact ? 12 : 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  Widget _radioTile<T>(BuildContext context, String label, T value) {
    return RadioListTile<T>(
      value: value,
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ① Basic Info
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBasicInfo(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    const categories = TaskCategory.values;

    return Column(
      children: [
        TextField(
          controller: _titleCtrl,
          onChanged: notifier.setTitle,
          decoration: const InputDecoration(hintText: 'Task title *'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descCtrl,
          onChanged: notifier.setDescription,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Description (optional)'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((c) {
            final active = form.category == c;
            return GestureDetector(
              onTap: () => notifier.setCategory(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  c.name[0].toUpperCase() + c.name.substring(1),
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ② Start Date & Alarm
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStartDateAlarm(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date + Time row
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: form.date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) notifier.setDate(picked);
                },
                child: _dateTile(
                  context,
                  card,
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Start Date',
                  value:
                      '${form.date.day} ${_months[form.date.month - 1]} ${form.date.year}',
                  accent: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: form.time,
                  );
                  if (picked != null) notifier.setTime(picked);
                },
                child: _timeTile(
                  context,
                  card,
                  label: 'Start Time',
                  value:
                      '${form.time.hour.toString().padLeft(2, '0')}:${form.time.minute.toString().padLeft(2, '0')}',
                  accent: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Start Alarm sub-header
        _subHeader(context, Icons.alarm_rounded, 'Start Alarm Type'),
        const SizedBox(height: 4),

        // Notification Only radio
        RadioGroup<AlarmMode>(
          groupValue: form.alarmMode,
          onChanged: (v) => notifier.setAlarmMode(v!),
          child: Column(
            children: [
              _radioTile(
                  context, 'Notification Only', AlarmMode.notificationOnly),
              _radioTile(context, 'Alarm Music (Custom)', AlarmMode.alarmMusic),
            ],
          ),
        ),

        if (form.alarmMode == AlarmMode.alarmMusic) ...[
          const SizedBox(height: 10),
          _alarmMusicCard(
            context,
            card,
            musicFile: form.musicFile,
            volume: form.volume,
            snoozeMinutes: form.snoozeMinutes,
            onChooseMusic: () =>
                _showMusicPickerSheet(context, notifier.setMusicFile),
            onVolumeChanged: notifier.setVolume,
            onSnoozeChanged: notifier.setSnooze,
          ),
        ],

        const SizedBox(height: 16),

        // Start reminders sub-section
        _subHeader(context, Icons.notifications_rounded, 'Start Reminders'),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Enable Reminders',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Switch(
                value: form.reminderEnabled,
                onChanged: notifier.toggleReminder),
          ],
        ),
        if (form.reminderEnabled) ...[
          const SizedBox(height: 10),
          ..._reminderChips(context, card, form.reminders,
              onRemove: notifier.removeReminder),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _showReminderSheet(
                context, notifier.addReminder, form.reminders),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Start Reminder'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ③ Due Date & Reminders
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDueDateReminders(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    final secondary = Theme.of(context).colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enable Due Date toggle
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.flag_rounded, size: 18, color: secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Set Due Date',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Switch(
                value: form.dueDateEnabled, onChanged: notifier.toggleDueDate),
          ],
        ),

        if (form.dueDateEnabled) ...[
          const SizedBox(height: 16),

          // Due Date + Time row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final initial =
                        form.dueDate ?? form.date.add(const Duration(days: 1));
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: form.date,
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) notifier.setDueDate(picked);
                  },
                  child: _dateTile(
                    context,
                    card,
                    icon: Icons.flag_rounded,
                    label: 'Due Date',
                    value: form.dueDate != null
                        ? '${form.dueDate!.day} ${_months[form.dueDate!.month - 1]} ${form.dueDate!.year}'
                        : 'Tap to set',
                    accent: secondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          form.dueTime ?? const TimeOfDay(hour: 17, minute: 0),
                    );
                    if (picked != null) notifier.setDueTime(picked);
                  },
                  child: _timeTile(
                    context,
                    card,
                    label: 'Due Time',
                    value: form.dueTime != null
                        ? '${form.dueTime!.hour.toString().padLeft(2, '0')}:${form.dueTime!.minute.toString().padLeft(2, '0')}'
                        : '--:--',
                    accent: secondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Due date reminders sub-section
          _subHeader(context, Icons.notifications_active_rounded,
              'Due Date Reminders'),
          const SizedBox(height: 8),

          Row(
            children: [
              Text('Enable Due Reminders',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch(
                  value: form.dueReminderEnabled,
                  onChanged: notifier.toggleDueReminder),
            ],
          ),

          if (form.dueReminderEnabled) ...[
            const SizedBox(height: 12),

            // Quick preset chips
            _buildDueReminderPresets(context, form, notifier),

            const SizedBox(height: 12),

            // Added reminders list
            if (form.dueReminders.isNotEmpty) ...[
              ..._reminderChips(context, card, form.dueReminders,
                  onRemove: notifier.removeDueReminder, accentColor: secondary),
              const SizedBox(height: 6),
            ],

            OutlinedButton.icon(
              onPressed: () => _showReminderSheet(
                  context, notifier.addDueReminder, form.dueReminders),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Due Reminder'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(color: secondary),
                foregroundColor: secondary,
              ),
            ),

            const SizedBox(height: 20),

            // Due alarm mode
            _subHeader(context, Icons.alarm_rounded, 'Due Reminder Alarm Type'),
            const SizedBox(height: 4),

            RadioGroup<AlarmMode>(
              groupValue: form.dueAlarmMode,
              onChanged: (v) => notifier.setDueAlarmMode(v!),
              child: Column(
                children: [
                  _radioTile(
                      context, 'Notification Only', AlarmMode.notificationOnly),
                  _radioTile(
                      context, 'Alarm Music (Custom)', AlarmMode.alarmMusic),
                ],
              ),
            ),

            if (form.dueAlarmMode == AlarmMode.alarmMusic) ...[
              const SizedBox(height: 10),
              _alarmMusicCard(
                context,
                card,
                musicFile: form.dueMusicFile,
                volume: form.dueVolume,
                snoozeMinutes: form.dueSnoozeMinutes,
                onChooseMusic: () =>
                    _showMusicPickerSheet(context, notifier.setDueMusicFile),
                onVolumeChanged: notifier.setDueVolume,
                onSnoozeChanged: notifier.setDueSnooze,
              ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildDueReminderPresets(
    BuildContext context,
    AddTaskFormState form,
    AddTaskFormNotifier notifier,
  ) {
    const presets = [
      '1 Day Before',
      '3 Hours Before',
      '1 Hour Before',
      '30 Minutes Before',
    ];
    final secondary = Theme.of(context).colorScheme.secondary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((p) {
        final added = form.dueReminders.contains(p);
        return GestureDetector(
          onTap: () {
            if (added) {
              notifier.removeDueReminder(p);
            } else {
              notifier.addDueReminder(p);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: added ? secondary : secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: added ? secondary : secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (added) ...[
                  const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(
                  p,
                  style: TextStyle(
                    color: added ? Colors.white : secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ④ Repeat
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRepeat(BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    const repeatOptions = RepeatType.values;
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: repeatOptions.map((r) {
            final active = form.repeat == r;
            return GestureDetector(
              onTap: () => notifier.setRepeat(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  r.name[0].toUpperCase() + r.name.substring(1),
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (form.repeat == RepeatType.weekly) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final active = form.weekDays[i];
              return GestureDetector(
                onTap: () => notifier.toggleWeekDay(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dayLabels[i],
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
        if (form.repeat == RepeatType.custom) ...[
          const SizedBox(height: 14),
          _buildCustomRepeat(context),
        ],
      ],
    );
  }

  Widget _buildCustomRepeat(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? darkCard : lightCard;
    final primary = Theme.of(context).colorScheme.primary;
    const units = ['Days', 'Weeks', 'Months', 'Years'];
    const endTypes = ['Never', 'On Date', 'After'];
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Every N [unit] row ────────────────────────────────────────
          Row(
            children: [
              Text('Every',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              // Counter − / N / +
              Container(
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(10)),
                      onTap: () {
                        if (_customInterval > 1) {
                          setState(() => _customInterval--);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child: Icon(Icons.remove_rounded,
                            size: 16, color: primary),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$_customInterval',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700, color: primary),
                      ),
                    ),
                    InkWell(
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10)),
                      onTap: () {
                        if (_customInterval < 99) {
                          setState(() => _customInterval++);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child:
                            Icon(Icons.add_rounded, size: 16, color: primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Unit dropdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primary.withValues(alpha: 0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _customIntervalUnit,
                    isDense: true,
                    items: units
                        .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: primary,
                                    fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _customIntervalUnit = v);
                    },
                  ),
                ),
              ),
            ],
          ),

          // ── Day picker (Weeks only) ───────────────────────────────────
          if (_customIntervalUnit == 'Weeks') ...[
            const SizedBox(height: 14),
            Text('On days',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final active = _customWeekDays[i];
                return GestureDetector(
                  onTap: () {
                    setState(() => _customWeekDays[i] = !_customWeekDays[i]);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: active ? primary : primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dayLabels[i],
                      style: TextStyle(
                        color: active ? Colors.white : primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // ── Ends section ──────────────────────────────────────────────
          Text('Ends',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: endTypes.map((e) {
              final active = _customEndType == e;
              return GestureDetector(
                onTap: () => setState(() => _customEndType = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? primary : primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            active ? primary : primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    e,
                    style: TextStyle(
                      color: active ? Colors.white : primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // ── Ends: On Date ─────────────────────────────────────────────
          if (_customEndType == 'On Date') ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _customEndDate ??
                      DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) {
                  setState(() => _customEndDate = picked);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 16, color: primary),
                    const SizedBox(width: 10),
                    Text(
                      _customEndDate != null
                          ? '${_customEndDate!.day} ${_months[_customEndDate!.month - 1]} ${_customEndDate!.year}'
                          : 'Select end date',
                      style: TextStyle(
                        color: _customEndDate != null
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : primary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Ends: After N occurrences ─────────────────────────────────
          if (_customEndType == 'After') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('After',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10)),
                        onTap: () {
                          if (_customEndAfterCount > 1) {
                            setState(() => _customEndAfterCount--);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child: Icon(Icons.remove_rounded,
                              size: 16, color: primary),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '$_customEndAfterCount',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.w700, color: primary),
                        ),
                      ),
                      InkWell(
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(10)),
                        onTap: () {
                          if (_customEndAfterCount < 999) {
                            setState(() => _customEndAfterCount++);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child:
                              Icon(Icons.add_rounded, size: 16, color: primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text('occurrences',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ⑤ Priority & Color Tag
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPriorityColor(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: TaskPriority.values.map((p) {
            final active = form.priority == p;
            Color pColor;
            switch (p) {
              case TaskPriority.low:
                pColor = priorityLow;
                break;
              case TaskPriority.medium:
                pColor = priorityMedium;
                break;
              case TaskPriority.high:
                pColor = priorityHigh;
                break;
            }
            return GestureDetector(
              onTap: () => notifier.setPriority(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? pColor : pColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: active ? pColor : pColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: active ? Colors.white : pColor,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      p.name[0].toUpperCase() + p.name.substring(1),
                      style: TextStyle(
                        color: active ? Colors.white : pColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text('Color Tag',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: colorTags.map((c) {
            final active = form.colorTag.toARGB32() == c.toARGB32();
            return GestureDetector(
              onTap: () => notifier.setColorTag(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                width: active ? 36 : 30,
                height: active ? 36 : 30,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border:
                      active ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: c.withValues(alpha: 0.5), blurRadius: 8)
                        ]
                      : null,
                ),
                child: active
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ⑥ Status Selector (edit mode only)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatusSelector(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    final currentStatus = form.status;

    const statusOptions = [
      (TaskStatus.upcoming, 'Upcoming', statusUpcoming),
      (TaskStatus.todo, 'Todo', statusTodo),
      (TaskStatus.inProgress, 'In Progress', statusInProgress),
      (TaskStatus.risk, 'At Risk', statusRisk),
      (TaskStatus.overdue, 'Overdue', statusOverdue),
      (TaskStatus.completed, 'Completed', statusCompleted),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statusOptions.map((entry) {
        final (status, label, color) = entry;
        final active = currentStatus == status;
        return GestureDetector(
          onTap: () => notifier.setStatus(status),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? color : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? color : color.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: active ? Colors.white : color,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared UI sub-components
  // ─────────────────────────────────────────────────────────────────────────

  Widget _dateTile(
    BuildContext context,
    Color card, {
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 5),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accent, fontWeight: FontWeight.w600, fontSize: 10)),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _timeTile(
    BuildContext context,
    Color card, {
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.access_time_rounded, size: 20, color: accent),
          const SizedBox(height: 5),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accent, fontWeight: FontWeight.w600, fontSize: 10)),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _subHeader(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }

  List<Widget> _reminderChips(
    BuildContext context,
    Color card,
    List<String> reminders, {
    required void Function(String) onRemove,
    Color? accentColor,
  }) {
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    return reminders
        .map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.alarm_rounded, size: 16, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(r,
                          style: Theme.of(context).textTheme.bodyMedium)),
                  GestureDetector(
                    onTap: () => onRemove(r),
                    child: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ))
        .toList();
  }

  Widget _alarmMusicCard(
    BuildContext context,
    Color card, {
    required String? musicFile,
    required double volume,
    required int snoozeMinutes,
    required VoidCallback onChooseMusic,
    required ValueChanged<double> onVolumeChanged,
    required ValueChanged<int> onSnoozeChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Music file picker row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.music_note_rounded,
                    size: 18, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      musicFile != null
                          ? AudioService.displayName(musicFile)
                          : 'No music selected',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (musicFile != null)
                      Text(
                          AudioService.isAsset(musicFile)
                              ? 'Built-in alarm'
                              : 'Custom file',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onChooseMusic,
                icon: const Icon(Icons.library_music_rounded, size: 16),
                label: const Text('Select'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          // Volume row
          Row(
            children: [
              const Icon(Icons.volume_up_rounded, size: 18),
              const SizedBox(width: 8),
              const Text('Volume'),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: volume,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${volume.round()}%',
                  onChanged: onVolumeChanged,
                ),
              ),
              SizedBox(
                width: 38,
                child: Text('${volume.round()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.right),
              ),
            ],
          ),

          // Snooze row
          Row(
            children: [
              const Icon(Icons.snooze_rounded, size: 18),
              const SizedBox(width: 8),
              const Text('Snooze'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: snoozeMinutes,
                underline: const SizedBox(),
                items: [5, 10, 15, 20, 30]
                    .map((v) =>
                        DropdownMenuItem(value: v, child: Text('$v min')))
                    .toList(),
                onChanged: (v) => onSnoozeChanged(v!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReminderSheet(
    BuildContext context,
    void Function(String) onAdd,
    List<String> current,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text('Select Reminder',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            ...reminderOptions
                .where((r) => r != 'Custom' && !current.contains(r))
                .map((r) => ListTile(
                      leading: const Icon(Icons.alarm_rounded),
                      title: Text(r),
                      onTap: () {
                        onAdd(r);
                        Navigator.pop(ctx);
                      },
                    )),
            if (reminderOptions
                .where((r) => r != 'Custom' && !current.contains(r))
                .isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('All options already added')),
              ),
          ],
        ),
      ),
    );
  }
}
