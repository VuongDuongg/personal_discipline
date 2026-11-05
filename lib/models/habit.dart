import 'dart:convert';
import 'package:flutter/material.dart';

class Habit {
  final String id;
  final String? userId;
  final String title;
  final String description;
  final int iconCode;
  final String colorHex;
  final String frequencyDays; // JSON string e.g. "[1,2,3,4,5,6,7]" (1=Mon, 7=Sun)
  final String? reminderTime; // Format "HH:mm"
  final int currentStreak;
  final String createdAt;
  final int isSynced; // 0: false, 1: true
  final int isDeleted; // 0: false, 1: true

  const Habit({
    required this.id,
    this.userId,
    required this.title,
    this.description = '',
    required this.iconCode,
    required this.colorHex,
    this.frequencyDays = '[1,2,3,4,5,6,7]',
    this.reminderTime,
    this.currentStreak = 0,
    required this.createdAt,
    this.isSynced = 0,
    this.isDeleted = 0,
  });

  // Helper getters
  Color get color {
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  IconData get icon {
    return IconData(iconCode, fontFamily: 'MaterialIcons');
  }

  List<int> get parsedFrequencyDays {
    try {
      final decoded = jsonDecode(frequencyDays) as List<dynamic>;
      return decoded.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return [1, 2, 3, 4, 5, 6, 7];
    }
  }

  bool isScheduledForWeekday(int weekday) {
    return parsedFrequencyDays.contains(weekday);
  }

  Habit copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    int? iconCode,
    String? colorHex,
    String? frequencyDays,
    String? reminderTime,
    int? currentStreak,
    String? createdAt,
    int? isSynced,
    int? isDeleted,
  }) {
    return Habit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      iconCode: iconCode ?? this.iconCode,
      colorHex: colorHex ?? this.colorHex,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      reminderTime: reminderTime ?? this.reminderTime,
      currentStreak: currentStreak ?? this.currentStreak,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'icon_code': iconCode,
      'color_hex': colorHex,
      'frequency_days': frequencyDays,
      'reminder_time': reminderTime,
      'current_streak': currentStreak,
      'created_at': createdAt,
      'is_synced': isSynced,
      'is_deleted': isDeleted,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      iconCode: (map['icon_code'] as num).toInt(),
      colorHex: map['color_hex'] as String,
      frequencyDays: (map['frequency_days'] as String?) ?? '[1,2,3,4,5,6,7]',
      reminderTime: map['reminder_time'] as String?,
      currentStreak: ((map['current_streak'] as num?) ?? 0).toInt(),
      createdAt: map['created_at'] as String,
      isSynced: ((map['is_synced'] as num?) ?? 0).toInt(),
      isDeleted: ((map['is_deleted'] as num?) ?? 0).toInt(),
    );
  }
}

