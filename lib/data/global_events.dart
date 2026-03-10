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

/// Returns all events from [extra] that fall on [date].
///
/// [extra] contains holidays fetched from Google Calendar ICS via
/// [HolidayService] and passed in from the [holidayProvider] in Riverpod.
List<GlobalEvent> getEventsForDate(DateTime date,
    {List<GlobalEvent> extra = const []}) {
  return [
    for (final e in extra)
      if (e.isOnDate(date)) e,
  ];
}
