import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/excel_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_toast.dart';
import '../utils/dialog_utils.dart';
import '../data/dummy_data.dart';
import 'birthday_screen.dart';
import 'music_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final card = isDark ? darkCard : lightCard;
    final vibration = ref.watch(vibrationEnabledProvider);
    final dnd = ref.watch(dndEnabledProvider);
    final accentIndex = ref.watch(accentColorIndexProvider);
    final fontScaleIndex = ref.watch(fontScaleIndexProvider);
    final defaultVol = ref.watch(defaultVolumeProvider);
    final defaultSnooze = ref.watch(defaultSnoozeProvider);
    final defaultMusic = ref.watch(defaultMusicProvider);
    final defaultRemind = ref.watch(defaultReminderProvider);
    final defaultNotifMusic = ref.watch(defaultNotifMusicProvider);
    final defaultNotifVol = ref.watch(defaultNotifVolumeProvider);
    final accentColors = [darkPrimary, darkSecondary, darkAccent, statusTodo];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile
          _buildProfileSection(context, ref, card, isDark),
          const SizedBox(height: 20),

          // ── Ulang Tahun ────────────────────────────────────────────────────
          _BirthdayNavCard(card: card),
          const SizedBox(height: 20),

          // ── Developer ──────────────────────────────────────────────────────
          _sectionTitle(context, 'Developer'),
          _buildCard(context, card, [
            _settingRowNav(context,
                icon: Icons.code_rounded,
                label: 'Informasi Developer',
                onTap: () => _showDeveloperModal(context, isDark, card)),
          ]),
          const SizedBox(height: 20),

          const SizedBox(height: 8),

          // ── Appearance ─────────────────────────────────────────────────────
          _sectionTitle(context, 'Appearance'),
          _buildCard(context, card, [
            _settingRow(
              context,
              icon: Icons.dark_mode_rounded,
              label: 'Theme',
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  DropdownMenuItem(
                      value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(
                      value: ThemeMode.system, child: Text('System')),
                ],
                onChanged: (v) {
                  ref.read(themeModeProvider.notifier).state = v!;
                  StorageService.saveThemeMode(v);
                },
              ),
            ),
            _divider(context),
            _settingRow(
              context,
              icon: Icons.color_lens_rounded,
              label: 'Accent Color',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(accentColors.length, (i) {
                  final active = accentIndex == i;
                  return GestureDetector(
                    onTap: () {
                      ref.read(accentColorIndexProvider.notifier).state = i;
                      StorageService.saveAccentIndex(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(left: 6),
                      width: active ? 28 : 22,
                      height: active ? 28 : 22,
                      decoration: BoxDecoration(
                        color: accentColors[i],
                        shape: BoxShape.circle,
                        border: active
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
            _divider(context),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_fields_rounded,
                          size: 20,
                          color: Theme.of(context).textTheme.bodyLarge?.color),
                      const SizedBox(width: 12),
                      Text(
                        'Text Size',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(width: 32),
                      ...List.generate(4, (i) {
                        const labels = ['Small', 'Normal', 'Large', 'XL'];
                        const scales = [0.85, 1.0, 1.15, 1.3];
                        final selected = i == fontScaleIndex;
                        final primary = Theme.of(context).colorScheme.primary;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () async {
                              ref.read(fontScaleIndexProvider.notifier).state =
                                  i;
                              await StorageService.saveFontScaleIndex(i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected
                                    ? primary
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06)),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 11 * scales[i],
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Alarm Defaults ─────────────────────────────────────────────────
          _sectionTitle(context, 'Alarm Defaults'),
          _buildCard(context, card, [
            // Default Music (navigate to music picker)
            InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MusicScreen()),
                );
                // Pick selection from provider
                final selected = ref.read(selectedMusicIdProvider);
                final music = ref.read(musicListProvider);
                final String fileToSave;
                if (selected.startsWith('custom_')) {
                  fileToSave = selected.substring('custom_'.length);
                } else {
                  final m = music.firstWhere((x) => x.id == selected,
                      orElse: () => music.first);
                  fileToSave = m.fileName;
                }
                ref.read(defaultMusicProvider.notifier).state = fileToSave;
                NotificationService.defaultAlarmMusic = fileToSave;
                await StorageService.saveDefaultMusic(fileToSave);
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  const Icon(Icons.music_note_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Default Alarm Music',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    fontWeight: FontWeight.w500, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(defaultMusic,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                ]),
              ),
            ),
            _divider(context),
            _settingRow(
              context,
              icon: Icons.volume_up_rounded,
              label: 'Default Volume',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    child: Slider(
                      value: defaultVol,
                      min: 0,
                      max: 100,
                      onChanged: (v) =>
                          ref.read(defaultVolumeProvider.notifier).state = v,
                      onChangeEnd: (v) {
                        StorageService.saveDefaultVolume(v);
                        NotificationService.defaultAlarmVolume = v / 100.0;
                      },
                    ),
                  ),
                  Text('${defaultVol.round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            _divider(context),
            _settingRow(
              context,
              icon: Icons.snooze_rounded,
              label: 'Snooze Duration',
              trailing: DropdownButton<int>(
                value: defaultSnooze,
                underline: const SizedBox(),
                items: [5, 10, 15, 20, 30]
                    .map((v) =>
                        DropdownMenuItem(value: v, child: Text('$v Minutes')))
                    .toList(),
                onChanged: (v) {
                  ref.read(defaultSnoozeProvider.notifier).state = v!;
                  StorageService.saveDefaultSnooze(v);
                },
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Notification Defaults ──────────────────────────────────────────
          _sectionTitle(context, 'Notification Defaults'),
          _buildCard(context, card, [
            InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MusicScreen()),
                );
                final selected = ref.read(selectedMusicIdProvider);
                final music = ref.read(musicListProvider);
                final String fileToSave;
                if (selected.startsWith('custom_')) {
                  fileToSave = selected.substring('custom_'.length);
                } else {
                  final m = music.firstWhere((x) => x.id == selected,
                      orElse: () => music.first);
                  fileToSave = m.fileName;
                }
                ref.read(defaultNotifMusicProvider.notifier).state = fileToSave;
                NotificationService.defaultNotifMusic = fileToSave;
                await StorageService.saveDefaultNotifMusic(fileToSave);
                await NotificationService.recreateNotifChannels();
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  const Icon(Icons.notifications_active_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Default Notification Music',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    fontWeight: FontWeight.w500, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(defaultNotifMusic,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                ]),
              ),
            ),
            _divider(context),
            _settingRow(
              context,
              icon: Icons.volume_up_rounded,
              label: 'Default Volume',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    child: Slider(
                      value: defaultNotifVol,
                      min: 0,
                      max: 100,
                      onChanged: (v) => ref
                          .read(defaultNotifVolumeProvider.notifier)
                          .state = v,
                      onChangeEnd: (v) {
                        StorageService.saveDefaultNotifVolume(v);
                        NotificationService.defaultNotifVolume = v / 100.0;
                      },
                    ),
                  ),
                  Text('${defaultNotifVol.round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Reminder Defaults ──────────────────────────────────────────────
          _sectionTitle(context, 'Reminder Defaults'),
          _buildCard(context, card, [
            _settingRow(
              context,
              icon: Icons.notifications_rounded,
              label: 'Default Reminder',
              trailing: DropdownButton<String>(
                value: defaultRemind,
                underline: const SizedBox(),
                items: reminderOptions
                    .where((r) => r != 'Custom')
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  ref.read(defaultReminderProvider.notifier).state = v!;
                  NotificationService.defaultReminder = v;
                  StorageService.saveDefaultReminder(v);
                  ref.read(taskListProvider.notifier).rescheduleAll();
                },
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Notification ───────────────────────────────────────────────────
          _sectionTitle(context, 'Notification'),
          _buildCard(context, card, [
            SwitchListTile(
              value: vibration,
              onChanged: (v) {
                ref.read(vibrationEnabledProvider.notifier).state = v;
                NotificationService.vibrationEnabled = v;
                StorageService.saveVibration(v);
                ref.read(taskListProvider.notifier).rescheduleAll();
              },
              title: const Text('Vibration'),
              secondary: const Icon(Icons.vibration_rounded),
              subtitle: const Text('Applies to all alarm & notification alerts',
                  style: TextStyle(fontSize: 11)),
              contentPadding: EdgeInsets.zero,
            ),
            _divider(context),
            SwitchListTile(
              value: dnd,
              onChanged: (v) {
                ref.read(dndEnabledProvider.notifier).state = v;
                NotificationService.dndEnabled = v;
                StorageService.saveDnd(v);
                ref.read(taskListProvider.notifier).rescheduleAll();
              },
              title: const Text('Do Not Disturb'),
              secondary: const Icon(Icons.do_not_disturb_on_rounded),
              subtitle: Text(
                  dnd
                      ? 'Active — normal notifications suppressed 22:00 – 07:00'
                      : 'Disabled — all notifications fire normally',
                  style: const TextStyle(fontSize: 11)),
              contentPadding: EdgeInsets.zero,
            ),
          ]),
          const SizedBox(height: 20),

          // ── Data & Backup ──────────────────────────────────────────────────
          _sectionTitle(context, 'Data & Backup'),
          _buildCard(context, card, [
            _settingRowNav(context,
                icon: Icons.file_download_rounded,
                label: 'Export Tasks to Excel',
                onTap: () => _exportTasks(context, ref)),
            _divider(context),
            _settingRowNav(context,
                icon: Icons.file_upload_rounded,
                label: 'Import Tasks from Excel',
                onTap: () => _showImportDialog(context, ref)),
            _divider(context),
            _settingRowNav(context,
                icon: Icons.delete_forever_rounded,
                label: 'Clear All Tasks',
                color: statusOverdue,
                onTap: () => _showClearDialog(context, ref)),
          ]),
          const SizedBox(height: 20),

          // ── About ──────────────────────────────────────────────────────────
          _sectionTitle(context, 'About'),
          _buildCard(context, card, [
            _settingRow(context,
                icon: Icons.info_outline_rounded,
                label: 'App Version',
                trailing: const Text('1.0.0',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            _divider(context),
            _settingRowNav(context,
                icon: Icons.privacy_tip_rounded,
                label: 'Privacy Policy',
                onTap: () => _showPrivacyPolicyDialog(context, isDark, card)),
            _divider(context),
            _settingRowNav(context,
                icon: Icons.star_rounded,
                label: 'Rate App',
                onTap: () => _rateApp()),
          ]),
          const SizedBox(height: 20),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Profile Section ───────────────────────────────────────────────────────
  Widget _buildProfileSection(
      BuildContext context, WidgetRef ref, Color card, bool isDark) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        gradient:
            LinearGradient(colors: [primary.withValues(alpha: 0.10), card]),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.person_rounded, color: primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Profile & Sync',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('This feature is under development',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: isDark ? darkTextSecondary : lightTextSecondary,
                      )),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () => AppToast.show(
                context, 'Auth & sync feature is under development'),
            icon: const Icon(Icons.construction_rounded, size: 18),
            label: const Text('Coming Soon',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  Widget _buildCard(BuildContext context, Color card, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
      child: Column(children: children),
    );
  }

  Widget _settingRow(BuildContext context,
      {required IconData icon,
      required String label,
      required Widget trailing,
      Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon,
            size: 20,
            color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color, fontWeight: FontWeight.w500, fontSize: 14)),
        ),
        trailing,
      ]),
    );
  }

  Widget _settingRowNav(BuildContext context,
      {required IconData icon,
      required String label,
      String? value,
      Color? color,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(icon,
              size: 20,
              color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    )),
          ),
          if (value != null) ...[
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
          ],
          Icon(Icons.chevron_right_rounded,
              size: 18,
              color: color ?? Theme.of(context).textTheme.bodyMedium?.color),
        ]),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(height: 1, color: Theme.of(context).dividerTheme.color);
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showScaleDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Tasks'),
        content: const Text(
            'Delete all tasks from this device? Custom music and birthday data will not be affected. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Cancel all notifications and clear storage
              await NotificationService.cancelAll();
              ref.read(taskListProvider.notifier).clearAll();
              if (context.mounted) {
                AppToast.show(
                  context,
                  'All tasks have been deleted.',
                  type: ToastType.warning,
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: statusOverdue, foregroundColor: Colors.white),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTasks(BuildContext context, WidgetRef ref) async {
    final tasks = ref.read(taskListProvider);
    if (tasks.isEmpty) {
      AppToast.show(context, 'No tasks to export.', type: ToastType.warning);
      return;
    }
    try {
      await ExcelService.exportTasks(tasks);
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Export failed: $e', type: ToastType.error);
      }
    }
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showScaleDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Tasks from Excel'),
        content: const Text(
          'Select import mode:\n\n'
          '• Merge – adds new tasks from the file without deleting existing tasks.\n\n'
          '• Replace All – deletes all existing tasks and replaces them with data from the file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runImport(context, ref, replace: false);
            },
            child: const Text('Merge'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runImport(context, ref, replace: true);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: statusOverdue, foregroundColor: Colors.white),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
  }

  Future<void> _runImport(BuildContext context, WidgetRef ref,
      {required bool replace}) async {
    try {
      final tasks = await ExcelService.importTasks();
      if (tasks == null) return; // user cancelled
      if (tasks.isEmpty) {
        if (context.mounted) {
          AppToast.show(context, 'No task data found in the file.',
              type: ToastType.warning);
        }
        return;
      }
      final count = await ref
          .read(taskListProvider.notifier)
          .importTasksBulk(tasks, replace: replace);
      if (context.mounted) {
        AppToast.show(
          context,
          replace
              ? '$count tasks imported successfully (all old data replaced).'
              : '$count new tasks added successfully.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, 'Import failed: $e', type: ToastType.error);
      }
    }
  }

  void _showPrivacyPolicyDialog(BuildContext context, bool isDark, Color card) {
    showScaleDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(children: [
                  Icon(Icons.privacy_tip_rounded,
                      color: Theme.of(ctx).colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy Policy',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
              ),
              Divider(height: 1, color: Theme.of(ctx).dividerTheme.color),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _privacySection(
                          ctx,
                          'Privacy Policy',
                          'Effective date: January 1, 2025\n\n'
                              'Smart Alarm & Task Scheduler ("App") is developed '
                              'by Agung Kurniawan as a freeware application. This '
                              'service is provided at no cost and is intended to be '
                              'used as is.\n\n'
                              'This Privacy Policy explains our policies regarding '
                              'the collection, use, and disclosure of personal '
                              'information when you use this App.'),
                      _privacySection(
                          ctx,
                          '1. Data Collection and Use',
                          'This App does not collect any personal data to external '
                              'servers. All data you enter — including task names, '
                              'schedules, reminders, and settings preferences — is '
                              'stored locally on your device using Android\'s built-in '
                              'storage mechanism (SharedPreferences). This data is '
                              'never transmitted, shared, or sold to third parties.'),
                      _privacySection(
                          ctx,
                          '2. Permissions Used',
                          '• Notifications — used to display reminders and task '
                              'alarms at the scheduled time.\n'
                              '• Exact Alarm (SCHEDULE_EXACT_ALARM) — '
                              'used so that alarms can ring at the exact time set by the user.\n'
                              '• Full Screen Intent — used so that the alarm screen '
                              'can appear even when the device screen is locked.\n'
                              '• Vibration — used for vibration during notifications '
                              'or alarms.\n'
                              '• Storage (READ_EXTERNAL_STORAGE, optional) — '
                              'used only if the user selects a music file from the device.'),
                      _privacySection(
                          ctx,
                          '3. Third-Party Services',
                          'This App does not integrate with any analytics, '
                              'advertising, or third-party tracking services. '
                              'No marketing SDK is included in this App.'),
                      _privacySection(
                          ctx,
                          '4. Data Security',
                          'We are committed to protecting your information. '
                              'All data is stored locally on your device '
                              'and cannot be accessed by others without physical '
                              'access to the device. We recommend enabling a screen '
                              'lock on your device for an additional layer of security.'),
                      _privacySection(
                          ctx,
                          '5. User Rights',
                          'You have full control over all data in this App. '
                              'You can delete all task data through Settings → '
                              'Data & Backup → Clear All Tasks, '
                              'or uninstall the App to permanently delete all data.'),
                      _privacySection(
                          ctx,
                          '6. Policy Changes',
                          'We may update this Privacy Policy from time to time. '
                              'Changes will be communicated through app updates. '
                              'Continued use of the App after any changes means '
                              'you accept the updated policy.'),
                      _privacySection(
                          ctx,
                          '7. Contact Us',
                          'If you have any questions about this Privacy Policy, '
                              'please contact us:\n\n'
                              'Email: agungklewang26@gmail.com\n'
                              'WhatsApp: +62 813-3164-0909'),
                    ],
                  ),
                ),
              ),
              // Footer button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('I Understand'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _privacySection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 6),
        Text(content,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 12.5, height: 1.55)),
      ]),
    );
  }

  void _rateApp() {
    const phone = '6281331640909';
    const message = 'Hi Kak Agung! 👋\n\n'
        'I want to rate the app:\n'
        '📱 *Smart Alarm & Task Scheduler*\n\n'
        'My rating: ⭐⭐⭐⭐⭐\n\n'
        'Comment: [Write your comment here...]\n\n'
        'Thank you for making such a great app! 🙌';
    final encoded = Uri.encodeComponent(message);
    launchUrl(
      Uri.parse('https://wa.me/$phone?text=$encoded'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _showDeveloperModal(BuildContext context, bool isDark, Color card) {
    final primary = Theme.of(context).colorScheme.primary;
    showScaleBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Icon(Icons.person_rounded, color: primary, size: 38),
            ),
            const SizedBox(height: 12),
            Text('Agung Kurniawan',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Mobile App Developer',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? darkTextSecondary : lightTextSecondary,
                    fontSize: 13)),
            const SizedBox(height: 24),
            _devContactTile(context,
                isDark: isDark,
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                label: 'WhatsApp',
                value: '081331640909', onTap: () {
              const phone = '6281331640909';
              const message = 'Hi Kak Agung! 👋\n\n'
                  'I am a user of:\n'
                  '📱 *Smart Alarm & Task Scheduler*\n\n'
                  'I would like to contact you regarding:\n'
                  '[Write your message here...]\n\n'
                  'Thank you! 🙌';
              final encoded = Uri.encodeComponent(message);
              launchUrl(
                Uri.parse('https://wa.me/$phone?text=$encoded'),
                mode: LaunchMode.externalApplication,
              );
            }),
            const SizedBox(height: 10),
            _devContactTile(context,
                isDark: isDark,
                icon: Icons.email_rounded,
                color: const Color(0xFFEA4335),
                label: 'Email',
                value: 'agungklewang26@gmail.com',
                onTap: () => launchUrl(
                    Uri.parse('mailto:agungklewang26@gmail.com'),
                    mode: LaunchMode.externalApplication)),
            const SizedBox(height: 10),
            _devContactTile(context,
                isDark: isDark,
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFFE1306C),
                label: 'Instagram',
                value: '@agungkurniawan.id',
                onTap: () => launchUrl(
                    Uri.parse('https://instagram.com/agungkurniawan.id'),
                    mode: LaunchMode.externalApplication)),
          ],
        ),
      ),
    );
  }

  Widget _devContactTile(BuildContext context,
      {required bool isDark,
      required IconData icon,
      required Color color,
      required String label,
      required String value,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? darkTextSecondary : lightTextSecondary,
                      fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          ),
          Icon(Icons.open_in_new_rounded, size: 16, color: color),
        ]),
      ),
    );
  }
}

// ─── Birthday Navigation Card ─────────────────────────────────────────────────

class _BirthdayNavCard extends ConsumerWidget {
  final Color card;
  const _BirthdayNavCard({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const birthdayColor = Color(0xFFFF6B9D);
    const purpleColor = Color(0xFF7B6EF6);
    final birthdays = ref.watch(birthdayListProvider);
    final count = birthdays.length;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BirthdayScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              birthdayColor.withValues(alpha: 0.18),
              purpleColor.withValues(alpha: 0.12),
            ],
          ),
          border: Border.all(
            color: birthdayColor.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    birthdayColor.withValues(alpha: 0.9),
                    purpleColor.withValues(alpha: 0.75),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: birthdayColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text('\u{1F382}', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Birthdays',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: birthdayColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count == 0
                        ? 'No birthday data yet'
                        : '$count birthday(s) added',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        ),
                  ),
                  if (count == 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: birthdayColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: birthdayColor.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Add now +',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: birthdayColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: birthdayColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: birthdayColor,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
