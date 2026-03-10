import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/music_model.dart';
import '../providers/app_providers.dart';
import '../services/audio_service.dart';
import '../theme/app_colors.dart';

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  String? _previewingId;
  String _searchQuery = '';

  String _fileForPlayback(MusicModel music) {
    if (music.id.startsWith('custom_')) {
      return music.id.substring('custom_'.length);
    }
    return music.fileName;
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _togglePreview(
      String musicId, String fileName, double volume) async {
    if (_previewingId == musicId) {
      await AudioService.instance.stop();
      setState(() => _previewingId = null);
    } else {
      await AudioService.instance.previewAsset(fileName, volume: volume);
      setState(() => _previewingId = musicId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMusic = ref.watch(musicListProvider);
    final selectedId = ref.watch(selectedMusicIdProvider);
    final categoryFilt = ref.watch(musicCategoryFilterProvider);
    final defaultVol = ref.watch(defaultVolumeProvider) / 100.0;
    final customFiles = ref.watch(customMusicFilesProvider);

    final customMusicModels = customFiles.map((path) {
      return MusicModel(
        id: 'custom_$path',
        fileName: AudioService.displayName(path),
        duration: '--',
        category: MusicCategory.custom,
      );
    }).toList();

    final selectedMusic = allMusic.firstWhere((m) => m.id == selectedId,
        orElse: () => customMusicModels.firstWhere((m) => m.id == selectedId,
            orElse: () => allMusic.first));

    final musicList = allMusic.where((m) {
      final matchCat = categoryFilt == null || m.category == categoryFilt;
      final matchSearch = _searchQuery.isEmpty ||
          m.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    final filteredCustom = customMusicModels.where((m) {
      final matchCat =
          categoryFilt == null || categoryFilt == MusicCategory.custom;
      final matchSearch = _searchQuery.isEmpty ||
          m.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    final mergedList = [...musicList, ...filteredCustom];

    final isSelectedPlaying = _previewingId == selectedId;

    return Scaffold(
      appBar: AppBar(title: const Text('Alarm Music Library')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
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
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelectedPlaying
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
                        '🎵 Selected: ${selectedMusic.fileName}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                      if (isSelectedPlaying)
                        const Text('▶ Preview playing...',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _togglePreview(
                      selectedId, _fileForPlayback(selectedMusic), defaultVol),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isSelectedPlaying ? '⏹ Stop' : '▶ Preview',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ),
              ]),
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
                _categoryChip(context, ref, null, 'All', categoryFilt),
                ...MusicCategory.values.map((c) => _categoryChip(
                    context,
                    ref,
                    c,
                    c.name[0].toUpperCase() + c.name.substring(1),
                    categoryFilt)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Music list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: mergedList.length,
              itemBuilder: (ctx, i) {
                final music = mergedList[i];
                final isCustom = music.id.startsWith('custom_');
                final isSelected = music.id == selectedId;
                final isPreviewing = _previewingId == music.id;
                return _MusicTile(
                  music: music,
                  isSelected: isSelected,
                  isPreviewing: isPreviewing,
                  onTap: () {
                    ref.read(selectedMusicIdProvider.notifier).state = music.id;
                    if (_previewingId != null && _previewingId != music.id) {
                      AudioService.instance.stop();
                      setState(() => _previewingId = null);
                    }
                  },
                  onFavorite: () => ref
                      .read(musicListProvider.notifier)
                      .toggleFavorite(music.id),
                  onPreview: () => _togglePreview(
                      music.id, _fileForPlayback(music), defaultVol),
                  onDelete: isCustom
                      ? () async {
                          final path = _fileForPlayback(music);
                          if (_previewingId == music.id) {
                            await AudioService.instance.stop();
                            setState(() => _previewingId = null);
                          }
                          if (selectedId == music.id) {
                            ref.read(selectedMusicIdProvider.notifier).state =
                                allMusic.isNotEmpty ? allMusic.first.id : '';
                          }
                          await ref
                              .read(customMusicFilesProvider.notifier)
                              .removeFile(path);
                        }
                      : null,
                );
              },
            ),
          ),
        ],
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
  final bool isPreviewing;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onPreview;
  final VoidCallback? onDelete;

  const _MusicTile({
    required this.music,
    required this.isSelected,
    required this.isPreviewing,
    required this.onTap,
    required this.onFavorite,
    required this.onPreview,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? darkCard : lightCard;
    final secondary = Theme.of(context).colorScheme.secondary;
    final textSec = Theme.of(context).textTheme.bodyMedium?.color;

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
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isPreviewing
                  ? secondary.withValues(alpha: 0.3)
                  : isSelected
                      ? secondary.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPreviewing ? Icons.equalizer_rounded : Icons.music_note_rounded,
              color: (isPreviewing || isSelected) ? secondary : textSec,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
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
                ]),
                const SizedBox(height: 3),
                Text('${music.duration} • ${music.categoryLabel}',
                    style: TextStyle(color: textSec, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onPreview,
            icon: Icon(isPreviewing
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline_rounded),
            iconSize: 22,
            color: isPreviewing ? statusRisk : secondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              iconSize: 22,
              color: statusRisk,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            )
          else
            IconButton(
              onPressed: onFavorite,
              icon: Icon(music.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded),
              iconSize: 22,
              color: music.isFavorite ? const Color(0xFFECC94B) : textSec,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ]),
      ),
    );
  }
}
