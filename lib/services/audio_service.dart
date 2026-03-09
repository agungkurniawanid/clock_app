import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Singleton audio service for alarm and preview playback.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  // MethodChannel that matches MainActivity.kt
  static const _volumeChannel =
      MethodChannel('com.example.flutter_clock_app/alarm_volume');

  bool get isPlaying => _isPlaying;

  /// Returns [true] when [file] is a bundled app asset (bare filename, no path
  /// separator). Returns [false] when it is an absolute device file path.
  static bool isAsset(String file) =>
      !file.contains('/') && !file.contains('\\');

  /// Returns the display name (last path segment) for any file identifier —
  /// works for both asset filenames and full device paths.
  static String displayName(String file) =>
      file.replaceAll('\\', '/').split('/').last;

  // ── Looping alarm play ────────────────────────────────────────────────────
  // Uses ALARM audio stream so the volume is independent of the phone's media /
  // ringer / notification volume.  Before playing, the native ALARM stream
  // volume is set to [volume] (0.0–1.0) × the stream's max; it is restored
  // when [stop] is called (dismiss or snooze).
  Future<void> playAsset(String fileName, {double volume = 1.0}) async {
    await stop();

    // Override ALARM stream volume to the user-configured level.
    await _setAlarmVolume(volume);

    // Route audio through ALARM stream (independent of media/ringer/notification).
    await _player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
    ));

    // Player volume is always 100 % of whatever stream level we just set.
    await _player.setVolume(1.0);
    await _player.setReleaseMode(ReleaseMode.loop);

    if (isAsset(fileName)) {
      await _player.play(AssetSource('music/$fileName'));
    } else {
      await _player.play(DeviceFileSource(fileName));
    }
    _isPlaying = true;
  }

  /// Single-play preview — does NOT touch the ALARM stream volume and uses the
  /// default audio context (media stream), suitable for the music picker / settings.
  Future<void> previewAsset(String fileName, {double volume = 1.0}) async {
    await stop();
    await _player.setVolume(volume.clamp(0.0, 1.0));
    await _player.setReleaseMode(ReleaseMode.release);
    if (isAsset(fileName)) {
      await _player.play(AssetSource('music/$fileName'));
    } else {
      await _player.play(DeviceFileSource(fileName));
    }
    _isPlaying = true;
    _player.onPlayerComplete.listen((_) => _isPlaying = false);
  }

  Future<void> setVolume(double volume) async =>
      await _player.setVolume(volume.clamp(0.0, 1.0));

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    // Restore the ALARM stream to what it was before we changed it.
    await _restoreAlarmVolume();
  }

  Future<void> dispose() async => await _player.dispose();

  // ── Native ALARM stream helpers ───────────────────────────────────────────

  /// Sets Android ALARM stream volume to [percentage] × max volume.
  Future<void> _setAlarmVolume(double percentage) async {
    try {
      await _volumeChannel.invokeMethod<void>(
        'setAlarmVolume',
        {'percentage': percentage.clamp(0.0, 1.0)},
      );
    } catch (_) {
      // Fail silently on iOS / desktop where the channel is not wired.
    }
  }

  /// Restores Android ALARM stream volume to the value saved before we changed it.
  Future<void> _restoreAlarmVolume() async {
    try {
      await _volumeChannel.invokeMethod<void>('restoreAlarmVolume');
    } catch (_) {
      // Fail silently on iOS / desktop.
    }
  }

  // ── Default alarm sound files (bundled in assets/music/) ─────────────────
  static const List<String> defaultSounds = [
    'alarm_clock.mp3',
    'alarm_tone.mp3',
    'fire_alarm.mp3',
    'iphone_alarm.mp3',
    'loud_alarm_sound.mp3',
    'loudest_alarm_clock.mp3',
    'samsung.mp3',
    'wake_up.mp3',
  ];

  static const String defaultAlarm = 'alarm_clock.mp3';
}
