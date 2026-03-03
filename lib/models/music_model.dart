enum MusicCategory { lofi, energetic, calm, nature, custom }

class MusicModel {
  final String id;
  final String fileName;
  final String duration;
  final MusicCategory category;
  final bool isDefault;
  final bool isFavorite;

  const MusicModel({
    required this.id,
    required this.fileName,
    required this.duration,
    required this.category,
    this.isDefault = false,
    this.isFavorite = false,
  });

  MusicModel copyWith({
    String? id,
    String? fileName,
    String? duration,
    MusicCategory? category,
    bool? isDefault,
    bool? isFavorite,
  }) {
    return MusicModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      isDefault: isDefault ?? this.isDefault,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  String get categoryLabel {
    switch (category) {
      case MusicCategory.lofi:
        return 'Lofi';
      case MusicCategory.energetic:
        return 'Energetic';
      case MusicCategory.calm:
        return 'Calm';
      case MusicCategory.nature:
        return 'Nature';
      case MusicCategory.custom:
        return 'Custom';
    }
  }
}
