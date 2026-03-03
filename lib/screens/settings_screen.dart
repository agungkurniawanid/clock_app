import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';

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
    final defaultVolume = ref.watch(defaultVolumeProvider);

    final accentColors = [darkPrimary, darkSecondary, darkAccent, statusTodo];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile
          _buildProfileSection(context, card),
          const SizedBox(height: 20),

          // Appearance
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
                onChanged: (v) =>
                    ref.read(themeModeProvider.notifier).state = v!,
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
                    onTap: () =>
                        ref.read(accentColorIndexProvider.notifier).state = i,
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
            _settingRow(
              context,
              icon: Icons.text_fields_rounded,
              label: 'Font Size',
              trailing: DropdownButton<String>(
                value: 'Medium',
                underline: const SizedBox(),
                items: ['Small', 'Medium', 'Large']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (_) {},
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Alarm Defaults
          _sectionTitle(context, 'Alarm Defaults'),
          _buildCard(context, card, [
            _settingRowNav(context,
                icon: Icons.music_note_rounded,
                label: 'Default Music',
                value: 'lofi_morning.mp3',
                onTap: () {}),
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
                      value: defaultVolume,
                      min: 0,
                      max: 100,
                      onChanged: (v) =>
                          ref.read(defaultVolumeProvider.notifier).state = v,
                    ),
                  ),
                  Text('${defaultVolume.round()}%',
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
                value: ref.watch(defaultSnoozeProvider),
                underline: const SizedBox(),
                items: [5, 10, 15, 20, 30]
                    .map((v) =>
                        DropdownMenuItem(value: v, child: Text('$v Minutes')))
                    .toList(),
                onChanged: (v) =>
                    ref.read(defaultSnoozeProvider.notifier).state = v!,
              ),
            ),
            _divider(context),
            _settingRow(
              context,
              icon: Icons.alarm_rounded,
              label: 'Default Mode',
              trailing: DropdownButton<String>(
                value: 'Alarm Music',
                underline: const SizedBox(),
                items: ['Alarm Music', 'Notification']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (_) {},
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Reminder Defaults
          _sectionTitle(context, 'Reminder Defaults'),
          _buildCard(context, card, [
            _settingRow(
              context,
              icon: Icons.notifications_rounded,
              label: 'Default Reminder',
              trailing: DropdownButton<String>(
                value: '1 Hour Before',
                underline: const SizedBox(),
                items: [
                  '1 Day Before',
                  '3 Hours Before',
                  '1 Hour Before',
                  '30 Minutes Before'
                ]
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (_) {},
              ),
            ),
            _divider(context),
            ListTile(
              leading: const Icon(Icons.add_alarm_rounded),
              title: const Text('Quick Add Reminders'),
              contentPadding: EdgeInsets.zero,
              subtitle: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ...['1h', '30m', '5m'].map((r) => Chip(
                        label: Text(r),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      )),
                  ActionChip(
                    label: const Icon(Icons.add_rounded, size: 16),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Notification
          _sectionTitle(context, 'Notification'),
          _buildCard(context, card, [
            SwitchListTile(
              value: vibration,
              onChanged: (v) =>
                  ref.read(vibrationEnabledProvider.notifier).state = v,
              title: const Text('Vibration'),
              secondary: const Icon(Icons.vibration_rounded),
              contentPadding: EdgeInsets.zero,
            ),
            _divider(context),
            SwitchListTile(
              value: dnd,
              onChanged: (v) => ref.read(dndEnabledProvider.notifier).state = v,
              title: const Text('Do Not Disturb'),
              secondary: const Icon(Icons.do_not_disturb_on_rounded),
              subtitle: dnd ? const Text('DND Hours: 22:00 – 07:00') : null,
              contentPadding: EdgeInsets.zero,
            ),
          ]),
          const SizedBox(height: 20),

          // Data & Backup
          _sectionTitle(context, 'Data & Backup'),
          _buildCard(context, card, [
            _settingRowNav(context,
                icon: Icons.save_rounded, label: 'Export Data', onTap: () {}),
            _divider(context),
            _settingRowNav(context,
                icon: Icons.download_rounded,
                label: 'Import Data',
                onTap: () {}),
            _divider(context),
            _settingRowNav(context,
                icon: Icons.delete_forever_rounded,
                label: 'Clear All Tasks',
                color: statusOverdue,
                onTap: () => _showClearDialog(context, ref)),
          ]),
          const SizedBox(height: 20),

          // About
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
                icon: Icons.star_rounded, label: 'Rate App', onTap: () {}),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, Color card) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            card,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded,
                color: Theme.of(context).colorScheme.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Name',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap to edit profile',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).textTheme.bodyMedium?.color),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Color card, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
      ),
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
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color, fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          trailing,
        ],
      ),
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
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
              ),
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
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).dividerTheme.color,
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Tasks'),
        content: const Text(
            'Are you sure you want to delete all tasks? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All tasks cleared (UI only)')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: statusOverdue),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
