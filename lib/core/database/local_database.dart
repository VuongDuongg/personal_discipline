import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../models/habit.dart';
import '../../models/habit_log.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;
  final _uuid = const Uuid();

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('habits_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Table: habits
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        icon_code INTEGER NOT NULL,
        color_hex TEXT NOT NULL,
        frequency_days TEXT NOT NULL,
        reminder_time TEXT,
        current_streak INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Table: habit_logs
    await db.execute('''
      CREATE TABLE habit_logs (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        user_id TEXT,
        completed_date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 1,
        is_synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE(habit_id, completed_date),
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_habits_deleted ON habits (is_deleted)');
    await db.execute('CREATE INDEX idx_logs_habit_date ON habit_logs (habit_id, completed_date)');
  }

  // ==========================================
  // HABIT CRUD
  // ==========================================

  Future<Habit> insertHabit(Habit habit) async {
    final db = await database;
    final toSave = habit.copyWith(isSynced: 0);
    await db.insert('habits', toSave.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return toSave;
  }

  Future<int> updateHabit(Habit habit) async {
    final db = await database;
    final toUpdate = habit.copyWith(isSynced: 0);
    return await db.update(
      'habits',
      toUpdate.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<int> deleteHabit(String habitId) async {
    final db = await database;
    // Soft delete to support sync to cloud
    return await db.update(
      'habits',
      {'is_deleted': 1, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<List<Habit>> getActiveHabits() async {
    final db = await database;
    final maps = await db.query(
      'habits',
      where: 'is_deleted = 0',
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => Habit.fromMap(e)).toList();
  }

  Future<Habit?> getHabitById(String id) async {
    final db = await database;
    final maps = await db.query(
      'habits',
      where: 'id = ? AND is_deleted = 0',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Habit.fromMap(maps.first);
    }
    return null;
  }

  // ==========================================
  // LOGS & CHECK-IN
  // ==========================================

  Future<Map<String, bool>> getCompletionStatusForDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'habit_logs',
      columns: ['habit_id', 'is_completed'],
      where: 'completed_date = ?',
      whereArgs: [date],
    );

    final result = <String, bool>{};
    for (var row in maps) {
      final habitId = row['habit_id'] as String;
      final isComp = (row['is_completed'] as int) == 1;
      result[habitId] = isComp;
    }
    return result;
  }

  Future<bool> toggleHabitCompletion(String habitId, String date, {String? userId}) async {
    final db = await database;

    // Check existing log
    final existing = await db.query(
      'habit_logs',
      where: 'habit_id = ? AND completed_date = ?',
      whereArgs: [habitId, date],
      limit: 1,
    );

    bool newStatus = true;
    if (existing.isNotEmpty) {
      final currentCompleted = (existing.first['is_completed'] as int) == 1;
      newStatus = !currentCompleted;
      await db.update(
        'habit_logs',
        {
          'is_completed': newStatus ? 1 : 0,
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      final log = HabitLog(
        id: _uuid.v4(),
        habitId: habitId,
        userId: userId,
        completedDate: date,
        isCompleted: 1,
        isSynced: 0,
      );
      await db.insert('habit_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      newStatus = true;
    }

    // Recalculate streak
    await _recalculateHabitStreak(habitId);

    return newStatus;
  }

  Future<void> _recalculateHabitStreak(String habitId) async {
    final db = await database;
    final habitMap = await db.query('habits', where: 'id = ?', whereArgs: [habitId], limit: 1);
    if (habitMap.isEmpty) return;

    final habit = Habit.fromMap(habitMap.first);
    final targetDays = habit.parsedFrequencyDays;

    final logs = await db.query(
      'habit_logs',
      where: 'habit_id = ? AND is_completed = 1',
      whereArgs: [habitId],
      orderBy: 'completed_date DESC',
    );

    final completedDates = logs.map((e) => e['completed_date'] as String).toSet();

    // Count backwards from today
    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);
    final todayStr = DateFormat('yyyy-MM-dd').format(checkDate);

    // If today is scheduled and not completed yet, check starting from yesterday
    bool todayCompleted = completedDates.contains(todayStr);
    if (!todayCompleted && targetDays.contains(checkDate.weekday)) {
      // Habit is scheduled for today but user hasn't done it yet;
      // Streak is preserved from yesterday!
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (true) {
      // Check if scheduled for this weekday
      if (targetDays.contains(checkDate.weekday)) {
        final dStr = DateFormat('yyyy-MM-dd').format(checkDate);
        if (completedDates.contains(dStr)) {
          streak++;
        } else {
          // Missed a scheduled day -> streak broken
          break;
        }
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
      // Safeguard: do not loop more than 365 days back
      if (streak > 365 || now.difference(checkDate).inDays > 365) break;
    }

    await db.update(
      'habits',
      {
        'current_streak': streak,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  // ==========================================
  // STATISTICS QUERIES (DAY / WEEK / MONTH)
  // ==========================================

  /// Daily Stats: For a specific date string "yyyy-MM-dd"
  Future<DailyStatsData> getDailyStats(String dateStr) async {
    final habits = await getActiveHabits();
    final parsedDate = DateTime.parse(dateStr);
    final weekday = parsedDate.weekday; // 1 = Mon ... 7 = Sun

    final scheduledHabits = habits.where((h) => h.isScheduledForWeekday(weekday)).toList();
    final totalScheduled = scheduledHabits.length;

    if (totalScheduled == 0) {
      return DailyStatsData(total: 0, completed: 0, percentage: 0.0);
    }

    final completions = await getCompletionStatusForDate(dateStr);
    int completedCount = 0;
    for (var habit in scheduledHabits) {
      if (completions[habit.id] == true) {
        completedCount++;
      }
    }

    final percentage = (completedCount / totalScheduled) * 100;
    return DailyStatsData(
      total: totalScheduled,
      completed: completedCount,
      percentage: percentage,
    );
  }

  /// Weekly Stats: 7 days of the week containing referenceDate (Mon -> Sun)
  Future<WeeklyStatsData> getWeeklyStats(DateTime referenceDate) async {
    final db = await database;
    // Calculate Monday of this week
    final int daysToSubtract = referenceDate.weekday - 1;
    final monday = DateTime(referenceDate.year, referenceDate.month, referenceDate.day)
        .subtract(Duration(days: daysToSubtract));

    final dayPoints = <DayCompletionPoint>[];
    final dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final countResult = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM habit_logs 
        WHERE completed_date = ? AND is_completed = 1
      ''', [dateStr])) ?? 0;

      dayPoints.add(
        DayCompletionPoint(
          date: date,
          dateStr: dateStr,
          label: dayNames[i],
          completedCount: countResult,
        ),
      );
    }

    return WeeklyStatsData(days: dayPoints);
  }

  /// Monthly Stats: 30 days history leading up to referenceDate
  Future<MonthlyStatsData> getMonthlyStats(DateTime referenceDate) async {
    final db = await database;
    final points = <TrendPoint>[];
    int totalCompletions = 0;

    for (int i = 29; i >= 0; i--) {
      final date = referenceDate.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final count = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM habit_logs 
        WHERE completed_date = ? AND is_completed = 1
      ''', [dateStr])) ?? 0;

      totalCompletions += count;
      points.add(TrendPoint(dateStr: dateStr, count: count));
    }

    // Best streak across active habits
    final bestStreakResult = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT MAX(current_streak) FROM habits WHERE is_deleted = 0
    ''')) ?? 0;

    return MonthlyStatsData(
      trendPoints: points,
      totalCompletionsIn30Days: totalCompletions,
      bestStreak: bestStreakResult,
    );
  }

  // ==========================================
  // SYNC QUERIES
  // ==========================================

  Future<List<Habit>> getUnsyncedHabits() async {
    final db = await database;
    final maps = await db.query('habits', where: 'is_synced = 0');
    return maps.map((e) => Habit.fromMap(e)).toList();
  }

  Future<List<HabitLog>> getUnsyncedLogs() async {
    final db = await database;
    final maps = await db.query('habit_logs', where: 'is_synced = 0');
    return maps.map((e) => HabitLog.fromMap(e)).toList();
  }

  Future<void> markHabitsAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate('UPDATE habits SET is_synced = 1 WHERE id IN ($placeholders)', ids);
  }

  Future<void> markLogsAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate('UPDATE habit_logs SET is_synced = 1 WHERE id IN ($placeholders)', ids);
  }

  Future<void> upsertHabitFromRemote(Habit habit) async {
    final db = await database;
    final toSave = habit.copyWith(isSynced: 1);
    await db.insert('habits', toSave.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertLogFromRemote(HabitLog log) async {
    final db = await database;
    final toSave = log.copyWith(isSynced: 1);
    await db.insert('habit_logs', toSave.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

// Data Transfer Objects for Stats
class DailyStatsData {
  final int total;
  final int completed;
  final double percentage;

  DailyStatsData({
    required this.total,
    required this.completed,
    required this.percentage,
  });
}

class DayCompletionPoint {
  final DateTime date;
  final String dateStr;
  final String label;
  final int completedCount;

  DayCompletionPoint({
    required this.date,
    required this.dateStr,
    required this.label,
    required this.completedCount,
  });
}

class WeeklyStatsData {
  final List<DayCompletionPoint> days;
  WeeklyStatsData({required this.days});
}

class TrendPoint {
  final String dateStr;
  final int count;
  TrendPoint({required this.dateStr, required this.count});
}

class MonthlyStatsData {
  final List<TrendPoint> trendPoints;
  final int totalCompletionsIn30Days;
  final int bestStreak;

  MonthlyStatsData({
    required this.trendPoints,
    required this.totalCompletionsIn30Days,
    required this.bestStreak,
  });
}

