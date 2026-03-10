import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_toast.dart';
import '../data/dummy_data.dart';
import '../models/birthday_model.dart';
import 'signup_screen.dart';
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
    final defaultVol = ref.watch(defaultVolumeProvider);
    final defaultSnooze = ref.watch(defaultSnoozeProvider);
    final defaultMusic = ref.watch(defaultMusicProvider);
    final defaultRemind = ref.watch(defaultReminderProvider);
    final defaultNotifMusic = ref.watch(defaultNotifMusicProvider);
    final defaultNotifVol = ref.watch(defaultNotifVolumeProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final userName = ref.watch(currentUserNameProvider);
    final userEmail = ref.watch(currentUserEmailProvider);
    final hasUnsynced = ref.watch(hasUnsyncedLocalTasksProvider);
    final accentColors = [darkPrimary, darkSecondary, darkAccent, statusTodo];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile
          _buildProfileSection(
              context, ref, card, isDark, isLoggedIn, userName, userEmail),
          const SizedBox(height: 20),

          // ── Ulang Tahun ────────────────────────────────────────────────────
          _BirthdaySection(card: card),
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

          // Sync Banner
          if (isLoggedIn && hasUnsynced) _buildSyncBanner(context, ref, isDark),
          if (isLoggedIn && hasUnsynced) const SizedBox(height: 20),
          if (!isLoggedIn || !hasUnsynced) const SizedBox(height: 8),

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

          // ── Account (logged in only) ───────────────────────────────────────
          if (isLoggedIn) ...[
            const SizedBox(height: 20),
            _sectionTitle(context, 'Akun'),
            _buildCard(context, card, [
              _settingRowNav(context,
                  icon: Icons.person_outline_rounded,
                  label: 'Edit Profil',
                  onTap: () {}),
              _divider(context),
              _settingRowNav(
                context,
                icon: Icons.logout_rounded,
                label: 'Keluar',
                color: statusOverdue,
                onTap: () => _showLogoutDialog(context, ref),
              ),
            ]),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Profile Section ───────────────────────────────────────────────────────
  Widget _buildProfileSection(BuildContext context, WidgetRef ref, Color card,
      bool isDark, bool isLoggedIn, String userName, String userEmail) {
    final primary = Theme.of(context).colorScheme.primary;

    if (!isLoggedIn) {
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
                  color: primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Icon(Icons.person_rounded, color: primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anda belum login',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('Masuk untuk sinkronisasi task ke cloud',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: isDark
                                  ? darkTextSecondary
                                  : lightTextSecondary,
                            )),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen())),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Masuk / Daftar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        gradient:
            LinearGradient(colors: [primary.withValues(alpha: 0.15), card]),
      ),
      child: Row(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Center(
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: TextStyle(
                  color: primary, fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(userName.isNotEmpty ? userName : 'Pengguna',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(userEmail,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: isDark ? darkTextSecondary : lightTextSecondary)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded,
            color: Theme.of(context).textTheme.bodyMedium?.color),
      ]),
    );
  }

  Widget _buildSyncBanner(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusRisk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: statusRisk.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: statusRisk.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: const Icon(Icons.cloud_upload_rounded,
              color: statusRisk, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Task lokal belum tersinkronisasi',
                style: TextStyle(
                    color: statusRisk,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text('Pindahkan task lokal Anda ke cloud.',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? darkTextSecondary : lightTextSecondary)),
          ]),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => _showSyncDialog(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: statusRisk,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sync',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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

  void _showSyncDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sinkronisasi Task'),
        content: const Text('Pindahkan semua task lokal ke akun cloud Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ref.read(hasUnsyncedLocalTasksProvider.notifier).state = false;
              await StorageService.saveHasUnsynced(false);
              if (context.mounted) {
                AppToast.show(
                  context,
                  'Task lokal berhasil disinkronisasi.',
                  type: ToastType.success,
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: statusRisk, foregroundColor: Colors.white),
            child: const Text('Sync Sekarang'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ref.read(isLoggedInProvider.notifier).state = false;
              ref.read(currentUserNameProvider.notifier).state = '';
              ref.read(currentUserEmailProvider.notifier).state = '';
              ref.read(hasUnsyncedLocalTasksProvider.notifier).state = true;
              await StorageService.clearAuthState();
              await StorageService.saveHasUnsynced(true);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: statusOverdue, foregroundColor: Colors.white),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Tasks'),
        content: const Text(
            'Hapus semua task dari perangkat ini? Custom music dan data ulang tahun tidak akan terpengaruh. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Cancel all notifications and clear storage
              await NotificationService.cancelAll();
              ref.read(taskListProvider.notifier).clearAll();
              if (context.mounted) {
                AppToast.show(
                  context,
                  'Semua task berhasil dihapus.',
                  type: ToastType.warning,
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: statusOverdue, foregroundColor: Colors.white),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context, bool isDark, Color card) {
    showDialog(
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
                          'Kebijakan Privasi',
                          'Tanggal berlaku: 1 Januari 2025\n\n'
                              'Smart Alarm & Task Scheduler ("Aplikasi") dikembangkan '
                              'oleh Agung Kurniawan sebagai aplikasi freeware. Layanan '
                              'ini disediakan tanpa biaya dan dimaksudkan untuk '
                              'digunakan apa adanya.\n\n'
                              'Kebijakan Privasi ini menjelaskan kebijakan kami '
                              'mengenai pengumpulan, penggunaan, dan pengungkapan '
                              'informasi pribadi apabila Anda menggunakan Aplikasi ini.'),
                      _privacySection(
                          ctx,
                          '1. Pengumpulan dan Penggunaan Data',
                          'Aplikasi ini tidak mengumpulkan data pribadi apa pun ke '
                              'server eksternal. Semua data yang Anda masukkan — '
                              'termasuk nama task, jadwal, pengingat, dan preferensi '
                              'pengaturan — disimpan secara lokal di perangkat Anda '
                              'menggunakan mekanisme penyimpanan bawaan Android '
                              '(SharedPreferences). Data tersebut tidak pernah '
                              'dikirim, dibagikan, atau dijual kepada pihak ketiga.'),
                      _privacySection(
                          ctx,
                          '2. Izin yang Digunakan',
                          '• Notifikasi — digunakan untuk menampilkan pengingat dan '
                              'alarm task pada waktu yang dijadwalkan.\n'
                              '• Alarm Tepat Waktu (SCHEDULE_EXACT_ALARM) — '
                              'digunakan agar alarm dapat berbunyi tepat pada waktu '
                              'yang ditentukan pengguna.\n'
                              '• Full Screen Intent — digunakan agar layar alarm '
                              'dapat tampil bahkan saat layar perangkat terkunci.\n'
                              '• Vibration — digunakan untuk getaran saat notifikasi '
                              'atau alarm berlangsung.\n'
                              '• Penyimpanan (READ_EXTERNAL_STORAGE, opsional) — '
                              'digunakan hanya jika pengguna memilih file musik dari '
                              'perangkat.'),
                      _privacySection(
                          ctx,
                          '3. Layanan Pihak Ketiga',
                          'Aplikasi ini tidak terintegrasi dengan layanan analitik, '
                              'iklan, atau pelacakan pihak ketiga apa pun. '
                              'Tidak ada SDK pemasaran yang disertakan di dalam '
                              'Aplikasi ini.'),
                      _privacySection(
                          ctx,
                          '4. Keamanan Data',
                          'Kami berkomitmen untuk melindungi informasi Anda. '
                              'Semua data disimpan secara lokal di perangkat Anda '
                              'dan tidak dapat diakses oleh pihak lain tanpa akses '
                              'fisik ke perangkat tersebut. Kami menyarankan Anda '
                              'untuk mengaktifkan kunci layar perangkat guna '
                              'menambah lapisan keamanan.'),
                      _privacySection(
                          ctx,
                          '5. Hak Pengguna',
                          'Anda memiliki kendali penuh atas semua data di dalam '
                              'Aplikasi ini. Anda dapat menghapus seluruh data task '
                              'melalui menu Settings → Data & Backup → Clear All Tasks, '
                              'atau menghapus instalasi Aplikasi untuk menghapus '
                              'seluruh data secara permanen.'),
                      _privacySection(
                          ctx,
                          '6. Perubahan Kebijakan',
                          'Kami dapat memperbarui Kebijakan Privasi ini dari waktu '
                              'ke waktu. Perubahan akan diinformasikan melalui '
                              'pembaruan aplikasi. Penggunaan Aplikasi secara '
                              'berkelanjutan setelah adanya perubahan berarti '
                              'Anda menyetujui kebijakan yang diperbarui tersebut.'),
                      _privacySection(
                          ctx,
                          '7. Hubungi Kami',
                          'Jika Anda memiliki pertanyaan mengenai Kebijakan Privasi '
                              'ini, silakan hubungi kami:\n\n'
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
                    child: const Text('Saya Mengerti'),
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
    const message = 'Halo Kak Agung! 👋\n\n'
        'Saya ingin memberikan rating untuk aplikasi:\n'
        '📱 *Smart Alarm & Task Scheduler*\n\n'
        'Rating saya: ⭐⭐⭐⭐⭐\n\n'
        'Komentar: [Tulis komentar Anda di sini...]\n\n'
        'Terima kasih sudah membuat aplikasi yang keren! 🙌';
    final encoded = Uri.encodeComponent(message);
    launchUrl(
      Uri.parse('https://wa.me/$phone?text=$encoded'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _showDeveloperModal(BuildContext context, bool isDark, Color card) {
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
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
              const message = 'Halo Kak Agung! 👋\n\n'
                  'Saya pengguna aplikasi:\n'
                  '📱 *Smart Alarm & Task Scheduler*\n\n'
                  'Saya ingin menghubungi Anda terkait:\n'
                  '[Tulis pesan Anda di sini...]\n\n'
                  'Terima kasih! 🙌';
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

// ─── Birthday Section Widget ──────────────────────────────────────────────────

class _BirthdaySection extends ConsumerStatefulWidget {
  final Color card;
  const _BirthdaySection({required this.card});

  @override
  ConsumerState<_BirthdaySection> createState() => _BirthdaySectionState();
}

class _BirthdaySectionState extends ConsumerState<_BirthdaySection> {
  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ags',
    'Sep',
    'Okt',
    'Nov',
    'Des'
  ];

  @override
  Widget build(BuildContext context) {
    final birthdays = ref.watch(birthdayListProvider);
    const birthdayColor = Color(0xFFFF6B9D);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Text(
            '🎂 Ulang Tahun',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: widget.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: birthdayColor.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              if (birthdays.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.cake_rounded,
                          size: 38,
                          color: birthdayColor.withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada data ulang tahun',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tambahkan ulang tahun Anda, keluarga, atau teman',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: birthdays.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                  ),
                  itemBuilder: (ctx, i) {
                    final entry = birthdays[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: entry.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: entry.color.withValues(alpha: 0.5),
                              width: 1.5),
                        ),
                        child: const Center(
                          child: Text('🎂', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      title: Text(
                        entry.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${entry.day} ${_monthNames[entry.month - 1]} · ${entry.typeLabel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: entry.color,
                            fontWeight: FontWeight.w600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () =>
                                _showBirthdaySheet(context, entry: entry),
                            icon: Icon(Icons.edit_rounded,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5)),
                          ),
                          IconButton(
                            onPressed: () => _confirmDelete(context, entry),
                            icon: const Icon(Icons.delete_rounded,
                                size: 18, color: Color(0xFFE53E3E)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              // Add button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showBirthdaySheet(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah Ulang Tahun'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: birthdayColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, BirthdayEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Ulang Tahun'),
        content: Text('Hapus ulang tahun "${entry.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(birthdayListProvider.notifier).deleteEntry(entry.id);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showBirthdaySheet(BuildContext context, {BirthdayEntry? entry}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BirthdayFormSheet(existing: entry),
    );
  }
}

// ── Birthday add/edit form ────────────────────────────────────────────────────

class _BirthdayFormSheet extends ConsumerStatefulWidget {
  final BirthdayEntry? existing;
  const _BirthdayFormSheet({this.existing});

  @override
  ConsumerState<_BirthdayFormSheet> createState() => _BirthdayFormSheetState();
}

class _BirthdayFormSheetState extends ConsumerState<_BirthdayFormSheet> {
  final _nameController = TextEditingController();
  int _month = DateTime.now().month;
  int _day = DateTime.now().day;
  BirthdayType _type = BirthdayType.self;
  Color _color = BirthdayEntry.paletteColors[0];

  static const List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _month = widget.existing!.month;
      _day = widget.existing!.day;
      _type = widget.existing!.type;
      _color = widget.existing!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _daysInMonth {
    // Use a leap year (2000) to allow Feb 29
    return DateTime(2000, _month + 1, 0).day;
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    final id =
        widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final entry = BirthdayEntry(
      id: id,
      name: _nameController.text.trim(),
      month: _month,
      day: _day.clamp(1, _daysInMonth),
      type: _type,
      color: _color,
    );
    if (widget.existing == null) {
      ref.read(birthdayListProvider.notifier).addEntry(entry);
    } else {
      ref.read(birthdayListProvider.notifier).updateEntry(entry);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const birthdayColor = Color(0xFFFF6B9D);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 28 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              const Text('🎂', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                widget.existing == null
                    ? 'Tambah Ulang Tahun'
                    : 'Edit Ulang Tahun',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name field
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nama',
              hintText: 'Contoh: Budi, Mama, dll.',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Date row: Month + Day
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bulan',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _month,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: List.generate(12, (i) {
                        return DropdownMenuItem(
                            value: i + 1, child: Text(_monthNames[i]));
                      }),
                      onChanged: (v) => setState(() {
                        _month = v!;
                        if (_day > _daysInMonth) _day = _daysInMonth;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tanggal',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _day.clamp(1, _daysInMonth),
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: List.generate(_daysInMonth, (i) {
                        return DropdownMenuItem(
                            value: i + 1, child: Text('${i + 1}'));
                      }),
                      onChanged: (v) => setState(() => _day = v!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Type chips
          Text('Tipe',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: BirthdayType.values.map((t) {
              final active = _type == t;
              final label = t == BirthdayType.self
                  ? '😊 Saya'
                  : t == BirthdayType.friend
                      ? '👫 Teman'
                      : '👨‍👩‍👧 Keluarga';
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? birthdayColor
                        : birthdayColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : birthdayColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Color picker
          Text('Warna',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: BirthdayEntry.paletteColors.map((c) {
              final isSelected = _color.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 32 : 28,
                  height: isSelected ? 32 : 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: c.withValues(alpha: 0.5), blurRadius: 6)
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _nameController.text.trim().isEmpty ? null : _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(widget.existing == null ? 'Simpan' : 'Perbarui'),
              style: ElevatedButton.styleFrom(
                backgroundColor: birthdayColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
