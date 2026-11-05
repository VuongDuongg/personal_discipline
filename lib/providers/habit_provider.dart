import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/database/local_database.dart';
import '../core/services/notification_service.dart';
import '../core/services/quote_service.dart';
import '../core/services/sync_service.dart';
import '../models/habit.dart';

// Currently selected date on the calendar strip
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

// Formatted string for selected date: "yyyy-MM-dd"
final selectedDateStringProvider = Provider<String>((ref) {
  final date = ref.watch(selectedDateProvider);
  return DateFormat('yyyy-MM-dd').format(date);
});

// Quote of the day provider
final dailyQuoteProvider = FutureProvider<QuoteData>((ref) async {
  return await QuoteService.instance.getDailyQuote();
});

// State of habits list
class HabitListNotifier extends StateNotifier<AsyncValue<List<Habit>>> {
  HabitListNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadHabits();
  }

  final Ref ref;
  final LocalDatabase _db = LocalDatabase.instance;
  final NotificationService _notifications = NotificationService.instance;
  final SyncService _sync = SyncService.instance;

  Future<void> loadHabits() async {
    try {
      final habits = await _db.getActiveHabits();
      state = AsyncValue.data(habits);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addHabit(Habit habit) async {
    try {
      await _db.insertHabit(habit);
      if (habit.reminderTime != null) {
        await _notifications.scheduleHabitReminder(habit);
      }
      await loadHabits();
      _sync.syncData();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateHabit(Habit habit) async {
    try {
      await _db.updateHabit(habit);
      await _notifications.cancelHabitReminder(habit.id);
      if (habit.reminderTime != null) {
        await _notifications.scheduleHabitReminder(habit);
      }
      await loadHabits();
      _sync.syncData();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteHabit(String habitId) async {
    try {
      await _db.deleteHabit(habitId);
      await _notifications.cancelHabitReminder(habitId);
      await loadHabits();
      ref.invalidate(dateCompletionsProvider);
      _sync.syncData();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleCompletion(String habitId, String dateStr) async {
    try {
      final userId = _sync.currentUserId;
      await _db.toggleHabitCompletion(habitId, dateStr, userId: userId);
      // Invalidate completions map so checkbox and dependent stats react
      ref.invalidate(dateCompletionsProvider(dateStr));
      // Reload habits for updated streaks
      await loadHabits();
      _sync.syncData();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final habitListNotifierProvider =
    StateNotifierProvider<HabitListNotifier, AsyncValue<List<Habit>>>((ref) {
  return HabitListNotifier(ref);
});

// Completions map for a specific date: habitId -> bool
final dateCompletionsProvider =
    FutureProvider.family<Map<String, bool>, String>((ref, dateStr) async {
  return await LocalDatabase.instance.getCompletionStatusForDate(dateStr);
});

// Daily stats for selected date (auto-reacts to habit additions/deletions/checks)
final dailyStatsProvider =
    FutureProvider.family<DailyStatsData, String>((ref, dateStr) async {
  // Watch habit list so adding/editing/deleting habits recomputes daily stats immediately
  ref.watch(habitListNotifierProvider);
  // Watch completions so ticking/unticking recalculates daily stats immediately
  ref.watch(dateCompletionsProvider(dateStr));
  return await LocalDatabase.instance.getDailyStats(dateStr);
});

