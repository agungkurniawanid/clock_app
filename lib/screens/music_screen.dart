import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/music_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';

class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicList = ref.watch(filteredMusicProvider);
    final allMusic = ref.watch(musicListProvider);
    final selectedId = ref.watch(selectedMusicIdProvider);
    final isPlaying = ref.watch(musicPreviewPlayingProvider);
    final categoryFilter = ref.watch(musicCategoryFilterProvider);
    final selectedMusic = allMusic.firstWhere((m) => m.id == selectedId,
        orElse: () => allMusic.first);

    return Scaffold(
      appBar: AppBar(title: const Text('Alarm Music Library')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search music...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),

          // Currently selected banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.secondary,
                    Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.equalizer_rounded
                          : Icons.music_note_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎵 Now Selected: ${selectedMusic.fileName}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        if (isPlaying)
                          const Text(
                            '▶ Preview playing...',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref
                        .read(musicPreviewPlayingProvider.notifier)
                        .state = !isPlaying,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isPlaying ? '⏹ Stop' : '▶ Preview',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Category filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _categoryChip(context, ref, null, 'All', categoryFilter),
                ...MusicCategory.values.map((c) => _categoryChip(
                    context,
                    ref,
                    c,
                    c.name[0].toUpperCase() + c.name.substring(1),
                    categoryFilter)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Music list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: musicList.length,
              itemBuilder: (ctx, i) {
                final music = musicList[i];
                final isSelected = music.id == selectedId;
                return _MusicTile(
                  music: music,
                  isSelected: isSelected,
                  onTap: () => ref
                      .read(selectedMusicIdProvider.notifier)
                      .state = music.id,
                  onFavorite: () => ref
                      .read(musicListProvider.notifier)
                      .toggleFavorite(music.id),
                  onPreview: () {
                    ref.read(selectedMusicIdProvider.notifier).state = music.id;
                    ref.read(musicPreviewPlayingProvider.notifier).state = true;
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Import Music from Device'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(BuildContext context, WidgetRef ref,
      MusicCategory? value, String label, MusicCategory? current) {
    final active = current == value;
    return GestureDetector(
      onTap: () => ref.read(musicCategoryFilterProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                active ? Colors.white : Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _MusicTile extends StatelessWidget {
  final MusicModel music;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onPreview;

  const _MusicTile({
    required this.music,
    required this.isSelected,
    required this.onTap,
    required this.onFavorite,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? darkCard : lightCard;
    final secondary = Theme.of(context).colorScheme.secondary;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: secondary, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? secondary.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: isSelected ? secondary : textSecondary,
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
                          music.fileName,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (music.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('DEFAULT',
                              style: TextStyle(
                                  color: secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${music.duration} • ${music.categoryLabel}',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onPreview,
              icon: const Icon(Icons.play_circle_outline_rounded),
              iconSize: 22,
              color: secondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              onPressed: onFavorite,
              icon: Icon(
                music.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
              ),
              iconSize: 22,
              color: music.isFavorite ? const Color(0xFFECC94B) : textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
