import 'package:flutter/material.dart';

/// A public holiday or notable event to display in the task list.
class GlobalEvent {
  final String name;
  final String emoji;
  final int month;
  final int day;

  /// 0 = repeats every year on that month+day.
  /// Non-zero = occurs only in that specific year.
  final int year;
  final Color color;

  const GlobalEvent({
    required this.name,
    required this.emoji,
    required this.month,
    required this.day,
    this.year = 0,
    required this.color,
  });

  /// Returns true if this event is active on the given [date].
  bool isOnDate(DateTime date) {
    if (month != date.month || day != date.day) return false;
    if (year == 0) return true;
    return year == date.year;
  }
}

// ── Cultural / Observance Days (same date every year, NOT official public
//    holidays → these are NOT returned by the nager.at API so we keep them
//    locally to avoid losing them when the API is used). ───────────────────────

const List<GlobalEvent> annualCulturalEvents = [
  GlobalEvent(
    name: 'Hari Valentine',
    emoji: '❤️',
    month: 2,
    day: 14,
    color: Color(0xFFFF6B9D),
  ),
  GlobalEvent(
    name: 'Hari Kartini',
    emoji: '🌸',
    month: 4,
    day: 21,
    color: Color(0xFFFF6B9D),
  ),
  GlobalEvent(
    name: 'Hari Pendidikan Nasional',
    emoji: '📚',
    month: 5,
    day: 2,
    color: Color(0xFF4A90E2),
  ),
  GlobalEvent(
    name: 'Hari Lingkungan Hidup Sedunia',
    emoji: '🌱',
    month: 6,
    day: 5,
    color: Color(0xFF38A169),
  ),
  GlobalEvent(
    name: 'Hari Kesaktian Pancasila',
    emoji: '🇮🇩',
    month: 10,
    day: 1,
    color: Color(0xFFE53E3E),
  ),
  GlobalEvent(
    name: 'Hari Batik Nasional',
    emoji: '🎨',
    month: 10,
    day: 2,
    color: Color(0xFFDD6B20),
  ),
  GlobalEvent(
    name: 'Hari Sumpah Pemuda',
    emoji: '✊',
    month: 10,
    day: 28,
    color: Color(0xFF7B6EF6),
  ),
  GlobalEvent(
    name: 'Hari Pahlawan',
    emoji: '🎖️',
    month: 11,
    day: 10,
    color: Color(0xFFE53E3E),
  ),
  GlobalEvent(
    name: 'Hari Ibu',
    emoji: '💐',
    month: 12,
    day: 22,
    color: Color(0xFFFF6B9D),
  ),
  GlobalEvent(
    name: 'Malam Tahun Baru',
    emoji: '🎆',
    month: 12,
    day: 31,
    color: Color(0xFF7B6EF6),
  ),
];

// Keep the old name as an alias so nothing else breaks during migration.
const List<GlobalEvent> annualHolidays = annualCulturalEvents;

/// Returns all global events that fall on [date].
///
/// [extra] should contain the API-fetched public holidays for the relevant
/// year(s) — passed in from the [holidayProvider] in Riverpod.
List<GlobalEvent> getEventsForDate(DateTime date,
    {List<GlobalEvent> extra = const []}) {
  final results = <GlobalEvent>[];
  for (final e in annualCulturalEvents) {
    if (e.isOnDate(date)) results.add(e);
  }
  for (final e in extra) {
    if (e.isOnDate(date)) results.add(e);
  }
  return results;
}
