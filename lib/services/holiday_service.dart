import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/global_events.dart';

/// Fetches public holidays dynamically from the nager.at API, automatically
/// detecting the user's country via GPS or IP geolocation. Results are cached
/// in SharedPreferences for 7 days so the API is not hammered on every launch.
class HolidayService {
  static const _nagerBase = 'https://date.nager.at/api/v3/PublicHolidays';
  static const _ipApiUrl = 'https://ipapi.co/json/';
  static const _nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';

  // Cache keys
  static const _keyCountry = 'hol_country_code';
  static const _keyCountrySource = 'hol_country_source';
  static const _tsPrefix = 'hol_ts_';
  static const _dataPrefix = 'hol_data_';

  static const _cacheTtl = Duration(days: 7);

  // ── Country detection ───────────────────────────────────────────────────────

  /// Returns a 2-letter ISO country code (e.g. "ID", "US").
  /// Detection order: cached → GPS+Nominatim → IP API → default "ID".
  static Future<String> detectCountryCode() async {
    final prefs = await SharedPreferences.getInstance();

    // Return cached value if present
    final cached = prefs.getString(_keyCountry);
    if (cached != null && cached.isNotEmpty) return cached;

    String? code;
    String source = 'default';

    // 1. Try GPS + Nominatim reverse geocoding
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
        final uri = Uri.parse(
          '$_nominatimUrl?lat=${pos.latitude}&lon=${pos.longitude}&format=json',
        );
        final resp = await http.get(uri, headers: {
          'User-Agent': 'SmartAlarmApp/1.0 (holiday detection)',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final address = body['address'] as Map<String, dynamic>?;
          final raw = address?['country_code']?.toString().toUpperCase();
          if (raw != null && raw.length == 2) {
            code = raw;
            source = 'gps';
          }
        }
      }
    } catch (_) {
      // GPS or network error → continue to IP fallback
    }

    // 2. Fallback: IP geolocation
    if (code == null) {
      try {
        final resp = await http
            .get(Uri.parse(_ipApiUrl))
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final raw = body['country_code']?.toString().toUpperCase();
          if (raw != null && raw.length == 2) {
            code = raw;
            source = 'ip';
          }
        }
      } catch (_) {
        // All detection failed
      }
    }

    code ??= 'ID';

    await prefs.setString(_keyCountry, code);
    await prefs.setString(_keyCountrySource, source);
    return code;
  }

  /// Returns the source used to detect the country: "gps", "ip", "default", or "cached".
  static Future<String> getDetectionSource() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCountrySource) ?? 'unknown';
  }

  /// Clears the cached country code so it is re-detected on the next call.
  static Future<void> resetCountryCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCountry);
    await prefs.remove(_keyCountrySource);
  }

  // ── Holiday fetching ────────────────────────────────────────────────────────

  /// Fetches public holidays for [year] in [countryCode].
  /// Returns cached data if fresh, otherwise calls the nager.at API.
  static Future<List<GlobalEvent>> fetchHolidays(
      int year, String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_dataPrefix${year}_$countryCode';
    final tsKey = '$_tsPrefix${year}_$countryCode';

    // Check cache freshness
    final ts = prefs.getInt(tsKey);
    final cached = prefs.getString(cacheKey);
    if (ts != null && cached != null) {
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age < _cacheTtl.inMilliseconds) {
        return _parseJson(cached);
      }
    }

    // Fetch from nager.at
    try {
      final uri = Uri.parse('$_nagerBase/$year/$countryCode');
      final resp = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        // Persist raw JSON so we can re-parse without a network call
        await prefs.setString(cacheKey, resp.body);
        await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
        return _parseJson(resp.body);
      }
    } catch (_) {
      // Network error → return cached data even if stale
      if (cached != null) return _parseJson(cached);
    }

    return [];
  }

  // ── Convenience: fetch current + next year ──────────────────────────────────

  /// Returns holidays for the current year AND the next year combined so the
  /// 30-day future window in the task list is always covered near year-end.
  static Future<List<GlobalEvent>> fetchRelevantHolidays(
      String countryCode) async {
    final now = DateTime.now();
    final current = await fetchHolidays(now.year, countryCode);
    final next = await fetchHolidays(now.year + 1, countryCode);
    return [...current, ...next];
  }

  // ── JSON parsing ────────────────────────────────────────────────────────────

  static List<GlobalEvent> _parseJson(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((h) {
        final dateStr = h['date'] as String; // "2026-03-20"
        final parts = dateStr.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);

        // Prefer localName, fall back to English name
        final localName = (h['localName'] as String? ?? '').trim();
        final englishName = (h['name'] as String? ?? '').trim();
        final displayName = localName.isNotEmpty ? localName : englishName;

        return GlobalEvent(
          name: displayName,
          emoji: _emoji(localName, englishName),
          month: month,
          day: day,
          year: year,
          color: _color(localName, englishName),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Emoji mapping ───────────────────────────────────────────────────────────

  static String _emoji(String local, String english) {
    final s = '${local.toLowerCase()} ${english.toLowerCase()}';

    if (_c(s, ['imlek', 'chinese new year', 'lunar new year'])) return '🏮';
    if (_c(s, ['idul fitri', 'eid al-fitr', 'eid ul-fitr', 'lebaran'])) {
      return '🌙';
    }
    if (_c(s, ['idul adha', 'eid al-adha', 'eid ul-adha', 'qurban'])) {
      return '🐑';
    }
    if (_c(s, ['nyepi'])) return '☯️';
    if (_c(s, ['waisak', 'vesak', 'buddha'])) return '☸️';
    if (_c(s, ['natal', 'christmas', 'xmas'])) return '🎄';
    if (_c(s, ['paskah', 'easter'])) return '🐣';
    if (_c(s, ['wafat yesus', 'good friday', 'jumat agung'])) return '✝️';
    if (_c(s, ['kenaikan yesus', 'ascension', 'kenaikan isa'])) return '✝️';
    if (_c(s, ['maulid', 'mawlid', 'muhammad', 'nabi'])) return '☪️';
    if (_c(s, ['isra', 'miraj'])) return '🌙';
    if (_c(s, [
      'tahun baru islam',
      'islamic new year',
      'hijri',
      'muharram',
      '1 muharram',
    ])) {
      return '🌙';
    }
    if (_c(s, ['kemerdekaan', 'independence', 'national day'])) return '🇮🇩';
    if (_c(s, ['pancasila'])) return '🇮🇩';
    if (_c(s, ['buruh', 'labor day', 'labour day', 'may day'])) return '🏭';
    if (_c(s, ['tahun baru', 'new year'])) return '🎉';
    return '🎌';
  }

  static bool _c(String s, List<String> keywords) =>
      keywords.any((k) => s.contains(k));

  // ── Color mapping ───────────────────────────────────────────────────────────

  static Color _color(String local, String english) {
    final s = '${local.toLowerCase()} ${english.toLowerCase()}';

    // Islamic holidays → green
    if (_c(s, [
      'idul',
      'eid',
      'maulid',
      'mawlid',
      'isra',
      'miraj',
      'hijri',
      'muharram',
      'islamic new year',
      'tahun baru islam',
    ])) {
      return const Color(0xFF38A169);
    }

    // Christian holidays → purple
    if (_c(s, [
      'natal',
      'christmas',
      'paskah',
      'easter',
      'wafat',
      'good friday',
      'kenaikan',
      'ascension',
    ])) {
      return const Color(0xFF7B6EF6);
    }

    // Chinese / Lunar → red
    if (_c(s, ['imlek', 'chinese', 'lunar'])) {
      return const Color(0xFFE53E3E);
    }

    // Hindu / Buddhist → teal
    if (_c(s, ['waisak', 'vesak', 'nyepi', 'buddha'])) {
      return const Color(0xFF4ECDC4);
    }

    // National / independence → red
    if (_c(s, ['kemerdekaan', 'independence', 'pancasila', 'national day'])) {
      return const Color(0xFFE53E3E);
    }

    // Labour day → orange
    if (_c(s, ['buruh', 'labor', 'labour', 'may day'])) {
      return const Color(0xFFDD6B20);
    }

    return const Color(0xFF7B6EF6);
  }
}
