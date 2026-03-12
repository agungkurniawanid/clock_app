import 'package:flutter/material.dart';

enum BirthdayType { self, friend, family }

class BirthdayEntry {
  final String id;
  final String name;
  final int month; // 1–12
  final int day; // 1–31
  final BirthdayType type;
  final Color color;

  const BirthdayEntry({
    required this.id,
    required this.name,
    required this.month,
    required this.day,
    required this.type,
    required this.color,
  });

  // ── Serialisation ─────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'month': month,
        'day': day,
        'type': type.index,
        'color': color.toARGB32(),
      };

  factory BirthdayEntry.fromJson(Map<String, dynamic> json) => BirthdayEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        month: json['month'] as int,
        day: json['day'] as int,
        type: BirthdayType.values[
            (json['type'] as int).clamp(0, BirthdayType.values.length - 1)],
        color: Color(json['color'] as int),
      );

  BirthdayEntry copyWith({
    String? id,
    String? name,
    int? month,
    int? day,
    BirthdayType? type,
    Color? color,
  }) =>
      BirthdayEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        month: month ?? this.month,
        day: day ?? this.day,
        type: type ?? this.type,
        color: color ?? this.color,
      );

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get typeLabel {
    switch (type) {
      case BirthdayType.self:
        return 'Me';
      case BirthdayType.friend:
        return 'Friend';
      case BirthdayType.family:
        return 'Family';
    }
  }

  static const List<Color> paletteColors = [
    Color(0xFFFF6B9D), // pink
    Color(0xFF7B6EF6), // purple
    Color(0xFF4ECDC4), // teal
    Color(0xFFFF8C42), // orange
    Color(0xFF4A90E2), // blue
    Color(0xFF38A169), // green
    Color(0xFFE53E3E), // red
    Color(0xFFDD6B20), // amber
  ];
}
