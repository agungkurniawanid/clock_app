import '../models/music_model.dart';

// ─── 8 Real Alarm Music Files (matching assets/music/*.mp3) ──────────────────
final List<MusicModel> dummyMusic = [
  const MusicModel(
    id: 'm1',
    fileName: 'alarm_clock.mp3',
    duration: '0:30',
    category: MusicCategory.calm,
    isDefault: true,
    isFavorite: true,
  ),
  const MusicModel(
    id: 'm2',
    fileName: 'alarm_tone.mp3',
    duration: '0:20',
    category: MusicCategory.calm,
    isFavorite: false,
  ),
  const MusicModel(
    id: 'm3',
    fileName: 'fire_alarm.mp3',
    duration: '0:15',
    category: MusicCategory.energetic,
    isFavorite: false,
  ),
  const MusicModel(
    id: 'm4',
    fileName: 'iphone_alarm.mp3',
    duration: '0:30',
    category: MusicCategory.calm,
    isFavorite: true,
  ),
  const MusicModel(
    id: 'm5',
    fileName: 'loud_alarm_sound.mp3',
    duration: '0:25',
    category: MusicCategory.energetic,
    isFavorite: false,
  ),
  const MusicModel(
    id: 'm6',
    fileName: 'loudest_alarm_clock.mp3',
    duration: '0:20',
    category: MusicCategory.energetic,
    isFavorite: false,
  ),
  const MusicModel(
    id: 'm7',
    fileName: 'samsung.mp3',
    duration: '0:30',
    category: MusicCategory.lofi,
    isFavorite: true,
  ),
  const MusicModel(
    id: 'm8',
    fileName: 'wake_up.mp3',
    duration: '0:35',
    category: MusicCategory.energetic,
    isFavorite: false,
  ),
];

// ─── Reminder Options ─────────────────────────────────────────────────────────
const List<String> reminderOptions = [
  '1 Day Before',
  '3 Hours Before',
  '1 Hour Before',
  '30 Minutes Before',
  '15 Minutes Before',
  '5 Minutes Before',
  'Custom',
];
