import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/global_events.dart';

/// Fetches public holidays from Google Calendar ICS feeds, automatically
/// detecting the user's country via GPS or IP geolocation. Results are cached
/// in SharedPreferences for 7 days.
class HolidayService {
  static const _ipApiUrl = 'https://ipapi.co/json/';
  static const _nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';

  // Cache keys
  static const _keyCountry = 'hol_country_code';
  static const _keyCountrySource = 'hol_country_source';
  static const _tsPrefix = 'hol_ts_ics_';
  static const _dataPrefix = 'hol_data_ics_';

  static const _cacheTtl = Duration(days: 7);

  // Maps ISO 3166-1 alpha-2 country codes to Google Calendar holiday locale IDs.
  static const Map<String, String> _gcalLocales = {
    'AD': 'en.andorra',
    'AE': 'en.united_arab_emirates',
    'AF': 'en.afghanistan',
    'AG': 'en.antigua_and_barbuda',
    'AL': 'en.albania',
    'AM': 'en.armenia',
    'AO': 'en.angola',
    'AR': 'en.argentina',
    'AT': 'en.austrian',
    'AU': 'en.australian',
    'AZ': 'en.azerbaijan',
    'BA': 'en.bosnia_and_herzegovina',
    'BB': 'en.barbados',
    'BD': 'en.bangladesh',
    'BE': 'en.belgium',
    'BF': 'en.burkina_faso',
    'BG': 'en.bulgarian',
    'BH': 'en.bahrain',
    'BI': 'en.burundi',
    'BJ': 'en.benin',
    'BN': 'en.brunei',
    'BO': 'en.bolivia',
    'BR': 'en.brazil',
    'BS': 'en.bahamas',
    'BT': 'en.bhutan',
    'BW': 'en.botswana',
    'BY': 'en.belarus',
    'BZ': 'en.belize',
    'CA': 'en.canadian',
    'CD': 'en.democratic_republic_of_congo',
    'CF': 'en.central_african_republic',
    'CG': 'en.republic_of_congo',
    'CH': 'en.swiss',
    'CI': 'en.ivory_coast',
    'CL': 'en.chile',
    'CM': 'en.cameroon',
    'CN': 'en.china',
    'CO': 'en.colombia',
    'CR': 'en.costa_rica',
    'CU': 'en.cuba',
    'CV': 'en.cape_verde',
    'CY': 'en.cyprus',
    'CZ': 'en.czech_republic',
    'DE': 'en.german',
    'DJ': 'en.djibouti',
    'DK': 'en.danish',
    'DM': 'en.dominica',
    'DO': 'en.dominican_republic',
    'DZ': 'en.algeria',
    'EC': 'en.ecuador',
    'EE': 'en.estonia',
    'EG': 'en.egypt',
    'ER': 'en.eritrea',
    'ES': 'en.spain',
    'ET': 'en.ethiopia',
    'FI': 'en.finland',
    'FJ': 'en.fiji',
    'FR': 'en.french',
    'GA': 'en.gabon',
    'GB': 'en.uk',
    'GD': 'en.grenada',
    'GE': 'en.georgia',
    'GH': 'en.ghana',
    'GM': 'en.gambia',
    'GN': 'en.guinea',
    'GQ': 'en.equatorial_guinea',
    'GR': 'en.greek',
    'GT': 'en.guatemala',
    'GW': 'en.guinea_bissau',
    'GY': 'en.guyana',
    'HK': 'en.hong_kong',
    'HN': 'en.honduras',
    'HR': 'en.croatia',
    'HT': 'en.haiti',
    'HU': 'en.hungarian',
    'ID': 'en.indonesian',
    'IE': 'en.irish',
    'IL': 'en.jewish_holidays',
    'IN': 'en.indian',
    'IQ': 'en.iraq',
    'IR': 'en.iran',
    'IS': 'en.iceland',
    'IT': 'en.italian',
    'JM': 'en.jamaica',
    'JO': 'en.jordan',
    'JP': 'en.japanese',
    'KE': 'en.kenya',
    'KG': 'en.kyrgyzstan',
    'KH': 'en.cambodia',
    'KI': 'en.kiribati',
    'KM': 'en.comoros',
    'KN': 'en.saint_kitts_and_nevis',
    'KP': 'en.north_korea',
    'KR': 'en.south_korea',
    'KW': 'en.kuwait',
    'KZ': 'en.kazakhstan',
    'LA': 'en.laos',
    'LB': 'en.lebanon',
    'LC': 'en.saint_lucia',
    'LI': 'en.liechtenstein',
    'LK': 'en.sri_lanka',
    'LR': 'en.liberia',
    'LS': 'en.lesotho',
    'LT': 'en.lithuania',
    'LU': 'en.luxembourg',
    'LV': 'en.latvian',
    'LY': 'en.libya',
    'MA': 'en.morocco',
    'MC': 'en.monaco',
    'MD': 'en.moldova',
    'ME': 'en.montenegro',
    'MG': 'en.madagascar',
    'MH': 'en.marshall_islands',
    'MK': 'en.north_macedonia',
    'ML': 'en.mali',
    'MM': 'en.myanmar',
    'MN': 'en.mongolia',
    'MR': 'en.mauritania',
    'MT': 'en.malta',
    'MU': 'en.mauritius',
    'MV': 'en.maldives',
    'MW': 'en.malawi',
    'MX': 'en.mexican',
    'MY': 'en.malaysia',
    'MZ': 'en.mozambique',
    'NA': 'en.namibia',
    'NE': 'en.niger',
    'NG': 'en.nigerian',
    'NI': 'en.nicaragua',
    'NL': 'en.netherlands',
    'NO': 'en.norway',
    'NP': 'en.nepal',
    'NR': 'en.nauru',
    'NZ': 'en.new_zealand',
    'OM': 'en.oman',
    'PA': 'en.panama',
    'PE': 'en.peru',
    'PG': 'en.papua_new_guinea',
    'PH': 'en.philippines',
    'PK': 'en.pakistan',
    'PL': 'en.polish',
    'PT': 'en.portugal',
    'PW': 'en.palau',
    'PY': 'en.paraguay',
    'QA': 'en.qatar',
    'RO': 'en.romanian',
    'RS': 'en.serbian',
    'RU': 'en.russian',
    'RW': 'en.rwanda',
    'SA': 'en.saudi_arabia',
    'SB': 'en.solomon_islands',
    'SC': 'en.seychelles',
    'SD': 'en.sudan',
    'SE': 'en.sweden',
    'SG': 'en.singapore',
    'SI': 'en.slovenian',
    'SK': 'en.slovak',
    'SL': 'en.sierra_leone',
    'SM': 'en.san_marino',
    'SN': 'en.senegal',
    'SO': 'en.somalia',
    'SR': 'en.suriname',
    'SS': 'en.south_sudan',
    'ST': 'en.sao_tome_and_principe',
    'SV': 'en.el_salvador',
    'SY': 'en.syria',
    'SZ': 'en.eswatini',
    'TD': 'en.chad',
    'TG': 'en.togo',
    'TH': 'en.thai',
    'TJ': 'en.tajikistan',
    'TL': 'en.east_timor',
    'TM': 'en.turkmenistan',
    'TN': 'en.tunisia',
    'TO': 'en.tonga',
    'TR': 'en.turkish',
    'TT': 'en.trinidad_and_tobago',
    'TV': 'en.tuvalu',
    'TW': 'en.taiwan',
    'TZ': 'en.tanzania',
    'UA': 'en.ukrainian',
    'UG': 'en.uganda',
    'US': 'en.usa',
    'UY': 'en.uruguay',
    'UZ': 'en.uzbekistan',
    'VA': 'en.vatican_city',
    'VC': 'en.saint_vincent_and_the_grenadines',
    'VE': 'en.venezuela',
    'VN': 'en.vietnamese',
    'VU': 'en.vanuatu',
    'WS': 'en.samoa',
    'YE': 'en.yemen',
    'ZA': 'en.south_africa',
    'ZM': 'en.zambia',
    'ZW': 'en.zimbabwe',
  };

  /// Returns the Google Calendar ICS URL for [countryCode].
  /// Falls back to Indonesia if the country is not mapped.
  static String _icsUrl(String countryCode) {
    final locale = _gcalLocales[countryCode.toUpperCase()] ?? 'en.indonesian';
    // '#' in the calendar ID must be %23 in the URL path
    return 'https://calendar.google.com/calendar/ical/'
        '$locale%23holiday@group.v.calendar.google.com/public/basic.ics';
  }

  // ── Country detection ───────────────────────────────────────────────────────

  /// Returns a 2-letter ISO country code (e.g. "ID", "US").
  /// Detection order: cached → GPS+Nominatim → IP API → default "ID".
  static Future<String> detectCountryCode() async {
    final prefs = await SharedPreferences.getInstance();

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

  /// Fetches all holidays for [countryCode] from Google Calendar ICS.
  /// Returns cached data if fresh, otherwise downloads the ICS feed.
  static Future<List<GlobalEvent>> fetchHolidays(String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_dataPrefix$countryCode';
    final tsKey = '$_tsPrefix$countryCode';

    // Check cache freshness
    final ts = prefs.getInt(tsKey);
    final cached = prefs.getString(cacheKey);
    if (ts != null && cached != null) {
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age < _cacheTtl.inMilliseconds) {
        return _parseCachedJson(cached);
      }
    }

    // Fetch ICS from Google Calendar
    try {
      final url = _icsUrl(countryCode);
      final resp = await http.get(Uri.parse(url), headers: {
        'Accept': 'text/calendar',
        'User-Agent': 'SmartAlarmApp/1.0 (holiday calendar)',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final events = _parseIcs(resp.body);
        // Persist as compact JSON so re-parsing skips a network call
        final jsonData = jsonEncode(events
            .map((e) => {
                  'name': e.name,
                  'emoji': e.emoji,
                  'month': e.month,
                  'day': e.day,
                  'year': e.year,
                  'color': e.color.value,
                })
            .toList());
        await prefs.setString(cacheKey, jsonData);
        await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
        return events;
      }
    } catch (_) {
      // Network error → return stale cache if available
      if (cached != null) return _parseCachedJson(cached);
    }

    return [];
  }

  /// Convenience wrapper that keeps the same API as the previous nager.at
  /// implementation so the rest of the app does not need to change.
  static Future<List<GlobalEvent>> fetchRelevantHolidays(
      String countryCode) async {
    return fetchHolidays(countryCode);
  }

  // ── ICS parsing ─────────────────────────────────────────────────────────────

  /// Parses a Google Calendar ICS response into [GlobalEvent] objects.
  /// Only includes events for the current year and the next two years.
  static List<GlobalEvent> _parseIcs(String icsBody) {
    final now = DateTime.now();
    final events = <GlobalEvent>[];

    // Unfold ICS lines: continuation lines begin with a space or tab.
    final unfolded = icsBody
        .replaceAll(RegExp(r'\r\n[ \t]'), '')
        .replaceAll(RegExp(r'\n[ \t]'), '');
    final lines = unfolded.split(RegExp(r'\r?\n'));

    bool inEvent = false;
    String? dtstart;
    String? summary;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        dtstart = null;
        summary = null;
      } else if (line == 'END:VEVENT') {
        if (inEvent && dtstart != null && summary != null) {
          final event = _parseVEvent(dtstart, summary, now);
          if (event != null) events.add(event);
        }
        inEvent = false;
      } else if (inEvent) {
        if (line.startsWith('DTSTART')) {
          final colonIdx = line.indexOf(':');
          if (colonIdx >= 0) dtstart = line.substring(colonIdx + 1).trim();
        } else if (line.startsWith('SUMMARY:')) {
          summary = line.substring(8).trim();
        }
      }
    }

    return events;
  }

  static GlobalEvent? _parseVEvent(
      String dtstart, String summary, DateTime now) {
    try {
      // Date can be YYYYMMDD or YYYYMMDDTHHMMSSZ; take only the date portion.
      final dateStr = dtstart.split('T').first.replaceAll('-', '');
      if (dateStr.length < 8) return null;

      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));

      // Keep events for the current year and the next two years only.
      if (year < now.year || year > now.year + 2) return null;

      // Unescape ICS text encoding
      final name = summary
          .replaceAll('\\n', ' ')
          .replaceAll('\\,', ',')
          .replaceAll('\\;', ';')
          .replaceAll('\\\\', '\\')
          .trim();

      if (name.isEmpty) return null;

      return GlobalEvent(
        name: name,
        emoji: _emoji(name),
        month: month,
        day: day,
        year: year,
        color: _color(name),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Cached JSON parsing ──────────────────────────────────────────────────────

  static List<GlobalEvent> _parseCachedJson(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((h) => GlobalEvent(
                name: h['name'] as String,
                emoji: h['emoji'] as String,
                month: h['month'] as int,
                day: h['day'] as int,
                year: h['year'] as int,
                color: Color(h['color'] as int),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Emoji mapping ────────────────────────────────────────────────────────────

  static String _emoji(String name) {
    final s = name.toLowerCase();

    if (_c(s, [
      'imlek',
      'chinese new year',
      'lunar new year',
      'tahun baru cina',
      'tahun baru china'
    ])) return '🏮';
    if (_c(s, [
      'idul fitri',
      'eid al-fitr',
      'eid ul-fitr',
      'lebaran',
      'idulfitri'
    ])) return '🌙';
    if (_c(
        s, ['idul adha', 'eid al-adha', 'eid ul-adha', 'qurban', 'iduladha']))
      return '🐑';
    if (_c(s, ['nyepi'])) return '☯️';
    if (_c(s, ['waisak', 'vesak', 'buddha', 'waisyak'])) return '☸️';
    if (_c(s, ['natal', 'christmas', 'xmas'])) return '🎄';
    if (_c(s, ['paskah', 'easter'])) return '🐣';
    if (_c(s, ['wafat yesus', 'good friday', 'jumat agung', 'wafat isa']))
      return '✝️';
    if (_c(
        s, ['kenaikan yesus', 'ascension', 'kenaikan isa', 'kenaikan kristus']))
      return '✝️';
    if (_c(s, ['maulid', 'mawlid', 'muhammad', 'nabi'])) return '☪️';
    if (_c(s, ['isra', 'miraj'])) return '🌙';
    if (_c(s, [
      'tahun baru islam',
      'islamic new year',
      'hijri',
      'muharram',
      '1 muharram'
    ])) return '🌙';
    if (_c(s, ['kemerdekaan', 'independence', 'national day'])) return '🇮🇩';
    if (_c(s, ['pancasila'])) return '🇮🇩';
    if (_c(s, ['buruh', 'labor day', 'labour day', 'may day'])) return '🏭';
    if (_c(s, ['tahun baru', 'new year', 'neujahr', 'año nuevo'])) return '🎉';
    if (_c(s, ['thanksgiving'])) return '🦃';
    if (_c(s, ['halloween'])) return '🎃';
    if (_c(s, ['valentine'])) return '❤️';
    if (_c(s, ['diwali', 'deepawali'])) return '🪔';
    if (_c(s, ['hanukkah', 'chanukah'])) return '🕎';
    if (_c(s, ['rosh hashana', 'yom kippur'])) return '✡️';
    if (_c(s, ['obon', 'tanabata'])) return '🏮';
    if (_c(s, ['songkran'])) return '💦';
    if (_c(s, ['bastille', 'quatorze juillet'])) return '🇫🇷';
    if (_c(s, ['anzac'])) return '🌺';
    return '🎌';
  }

  static bool _c(String s, List<String> keywords) =>
      keywords.any((k) => s.contains(k));

  // ── Color mapping ────────────────────────────────────────────────────────────

  static Color _color(String name) {
    final s = name.toLowerCase();

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
      'tahun baru islam'
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
      'ascension'
    ])) {
      return const Color(0xFF7B6EF6);
    }

    // Chinese / Lunar → red
    if (_c(s, ['imlek', 'chinese', 'lunar', 'cina', 'china'])) {
      return const Color(0xFFE53E3E);
    }

    // Hindu / Buddhist → teal
    if (_c(s, ['waisak', 'vesak', 'nyepi', 'buddha', 'diwali', 'deepawali'])) {
      return const Color(0xFF4ECDC4);
    }

    // Jewish → blue
    if (_c(s,
        ['hanukkah', 'chanukah', 'rosh hashana', 'yom kippur', 'passover'])) {
      return const Color(0xFF2B6CB0);
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
