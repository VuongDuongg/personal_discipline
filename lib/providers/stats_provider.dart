import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/local_database.dart';
import 'habit_provider.dart';

enum StatsPeriod { day, week, month }

final selectedStatsPeriodProvider = StateProvider<StatsPeriod>((ref) => StatsPeriod.day);

final weeklyStatsProvider = FutureProvider<WeeklyStatsData>((ref) async {
  // Watch habit list so adding/editing/deleting/toggling habits refreshes weekly stats
  ref.watch(habitListNotifierProvider);
  final now = DateTime.now();
  return await LocalDatabase.instance.getWeeklyStats(now);
});

final monthlyStatsProvider = FutureProvider<MonthlyStatsData>((ref) async {
  // Watch habit list so adding/editing/deleting/toggling habits refreshes monthly stats
  ref.watch(habitListNotifierProvider);
  final now = DateTime.now();
  return await LocalDatabase.instance.getMonthlyStats(now);
});
