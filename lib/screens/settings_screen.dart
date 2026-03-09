import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../data/dummy_data.dart';
import 'signup_screen.dart';
import 'music_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode    = ref.watch(themeModeProvider);
    final isDark       = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final card         = isDark ? darkCard : lightCard;
    final vibration    = ref.watch(vibrationEnabledProvider);
    final dnd          = ref.watch(dndEnabledProvider);
    final accentIndex  = ref.watch(accentColorIndexProvider);
    final defaultVol   = ref.watch(defaultVolumeProvider);
    final defaultSnooze = ref.watch(defaultSnoozeProvider);
    final defaultMusic = ref.watch(defaultMusicProvider);
    final defaultRemind = ref.watch(defaultReminderProvider);
    final isLoggedIn   = ref.watch(isLoggedInProvider);
    final userName     = ref.watch(currentUserNameProvider);
    final userEmail    = ref.watch(currentUserEmailProvider);
    final hasUnsynced  = ref.watch(hasUnsyncedLocalTasksProvider);
    final accentColors = [darkPrimary, darkSecondary, darkAccent, statusTodo];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile
          _buildProfileSection(
              context, ref, card, isDark, isLoggedIn, userName, userEmail),
          const SizedBox(height: 12),

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
                  DropdownMenuItem(value: ThemeMode.dark,   child: Text('Dark')),
                  DropdownMenuItem(value: ThemeMode.light,  child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
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
                final music    = ref.read(musicListProvider);
                final m = music.firstWhere((x) => x.id == selected,
                    orElse: () => music.first);
                ref.read(defaultMusicProvider.notifier).state = m.fileName;
                await StorageService.saveDefaultMusic(m.fileName);
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  const Icon(Icons.music_note_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Default Music',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w500,
                                fontSize: 14)),
                  ),
                  // Preview button
                  GestureDetector(
                    onTap: () => _previewDefaultMusic(context, defaultMusic,
                        defaultVol / 100.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('▶  Preview',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(defaultMusic,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18,
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
                      min: 0, max: 100,
                      onChanged: (v) =>
                          ref.read(defaultVolumeProvider.notifier).state = v,
                      onChangeEnd: (v) => StorageService.saveDefaultVolume(v),
                    ),
                  ),
                  Text('${defaultVol.round()}%',
                      style: Theme.of(context).textTheme.bodySmall
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
                    .map((v) => DropdownMenuItem(
                        value: v, child: Text('$v Minutes')))
                    .toList(),
                onChanged: (v) {
                  ref.read(defaultSnoozeProvider.notifier).state = v!;
                  StorageService.saveDefaultSnooze(v);
                },
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
                  StorageService.saveDefaultReminder(v);
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
                StorageService.saveVibration(v);
              },
              title: const Text('Vibration'),
              secondary: const Icon(Icons.vibration_rounded),
              contentPadding: EdgeInsets.zero,
            ),
            _divider(context),
            SwitchListTile(
              value: dnd,
              onChanged: (v) {
                ref.read(dndEnabledProvider.notifier).state = v;
                StorageService.saveDnd(v);
              },
              title: const Text('Do Not Disturb'),
              secondary: const Icon(Icons.do_not_disturb_on_rounded),
              subtitle:
                  dnd ? const Text('DND Hours: 22:00 – 07:00') : null,
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
                onTap: () {}),
            _divider(context),
            _settingRowNav(context,
                icon: Icons.star_rounded,
                label: 'Rate App',
                onTap: () {}),
          ]),
          const SizedBox(height: 20),

          // ── Developer ──────────────────────────────────────────────────────
          _sectionTitle(context, 'Developer'),
          _buildCard(context, card, [
            _settingRowNav(context,
                icon: Icons.code_rounded,
                label: 'Informasi Developer',
                onTap: () => _showDeveloperModal(context, isDark, card)),
          ]),

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
          gradient: LinearGradient(
              colors: [primary.withValues(alpha: 0.10), card]),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Icon(Icons.person_rounded, color: primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Anda belum login',
                    style: Theme.of(context).textTheme.titleMedium
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
        gradient: LinearGradient(
            colors: [primary.withValues(alpha: 0.15), card]),
      ),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.2),
              shape: BoxShape.circle),
          child: Center(
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: TextStyle(color: primary, fontSize: 24,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(userName.isNotEmpty ? userName : 'Pengguna',
                style: Theme.of(context).textTheme.titleMedium
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
        border: Border.all(color: statusRisk.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: statusRisk.withValues(alpha: 0.2),
              shape: BoxShape.circle),
          child: const Icon(Icons.cloud_upload_rounded,
              color: statusRisk, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Task lokal belum tersinkronisasi',
                style: TextStyle(color: statusRisk, fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text('Pindahkan task lokal Anda ke cloud.',
                style: TextStyle(fontSize: 12,
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sync',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    );
  }

  // ── Preview music ─────────────────────────────────────────────────────────
  void _previewDefaultMusic(
      BuildContext context, String fileName, double volume) async {
    await AudioService.instance.previewAsset(fileName, volume: volume);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing: $fileName'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Stop',
            onPressed: () => AudioService.instance.stop(),
          ),
        ),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  Widget _buildCard(
      BuildContext context, Color card, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: card, borderRadius: BorderRadius.circular(18)),
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
        Icon(icon, size: 20,
            color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 14)),
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
          Icon(icon, size: 20,
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
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
          ],
          Icon(Icons.chevron_right_rounded, size: 18,
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
        content: const Text(
            'Pindahkan semua task lokal ke akun cloud Anda?'),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Task lokal berhasil disinkronisasi.'),
                  behavior: SnackBarBehavior.floating,
                ));
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
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
                backgroundColor: statusOverdue,
                foregroundColor: Colors.white),
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
            'Hapus semua task dari perangkat ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Cancel all notifications and clear storage
              await NotificationService.cancelAll();
              ref.read(taskListProvider.notifier).clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Semua task berhasil dihapus.'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: statusOverdue,
                foregroundColor: Colors.white),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

  void _showDeveloperModal(
      BuildContext context, bool isDark, Color card) {
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 72, height: 72,
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
            _devContactTile(context, isDark: isDark,
                icon: Icons.chat_rounded, color: const Color(0xFF25D366),
                label: 'WhatsApp', value: '081331640909',
                onTap: () => launchUrl(Uri.parse('https://wa.me/6281331640909'),
                    mode: LaunchMode.externalApplication)),
            const SizedBox(height: 10),
            _devContactTile(context, isDark: isDark,
                icon: Icons.email_rounded, color: const Color(0xFFEA4335),
                label: 'Email', value: 'agungklewang26@gmail.com',
                onTap: () => launchUrl(
                    Uri.parse('mailto:agungklewang26@gmail.com'),
                    mode: LaunchMode.externalApplication)),
            const SizedBox(height: 10),
            _devContactTile(context, isDark: isDark,
                icon: Icons.camera_alt_rounded, color: const Color(0xFFE1306C),
                label: 'Instagram', value: '@agungkurniawan.id',
                onTap: () => launchUrl(
                    Uri.parse('https://instagram.com/agungkurniawan.id'),
                    mode: LaunchMode.externalApplication)),
          ],
        ),
      ),
    );
  }

  Widget _devContactTile(BuildContext context,
      {required bool isDark, required IconData icon, required Color color,
      required String label, required String value,
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
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? darkTextSecondary
                              : lightTextSecondary,
                          fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          ),
          Icon(Icons.open_in_new_rounded, size: 16, color: color),
        ]),
      ),
    );
  }
}
