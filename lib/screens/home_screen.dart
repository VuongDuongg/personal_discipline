import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/sync_service.dart';
import '../providers/habit_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/daily_progress_card.dart';
import '../widgets/habit_tile.dart';
import '../widgets/week_calendar_strip.dart';
import 'add_edit_habit_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _isSyncing = false;

  Future<void> _handleManualSync() async {
    setState(() => _isSyncing = true);
    final result = await SyncService.instance.syncData();
    setState(() => _isSyncing = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: result.status == SyncResultStatus.success
            ? Colors.green.shade700
            : (result.status == SyncResultStatus.notAuthenticated
                ? Colors.amber.shade900
                : Colors.blueGrey),
      ),
    );

    // Refresh habits after sync
    ref.read(habitListNotifierProvider.notifier).loadHabits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHabitListTab(),
          const StatisticsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Thói quen',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Thống kê',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditHabitScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm thói quen'),
            )
          : null,
    );
  }

  Widget _buildHabitListTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedDate = ref.watch(selectedDateProvider);
    final dateStr = ref.watch(selectedDateStringProvider);
    final habitsAsync = ref.watch(habitListNotifierProvider);
    final completionsAsync = ref.watch(dateCompletionsProvider(dateStr));

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          floating: true,
          pinned: false,
          title: const Row(
            children: [
              Icon(Icons.bolt, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text(
                'Kỷ Luật Mỗi Ngày',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          actions: [
            // Cloud Sync Button
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_outlined),
              tooltip: 'Đồng bộ Supabase',
              onPressed: _isSyncing ? null : _handleManualSync,
            ),
            // Theme Mode Toggle
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              tooltip: isDark ? 'Chế độ Sáng' : 'Chế độ Tối',
              onPressed: () {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),

        // 1. Week Calendar Strip
        const SliverToBoxAdapter(
          child: WeekCalendarStrip(),
        ),

        // 2. Daily Progress Card
        const SliverToBoxAdapter(
          child: DailyProgressCard(),
        ),

        // Header: Danh sách thói quen hôm nay
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thói quen trong ngày',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                habitsAsync.when(
                  data: (habits) {
                    final todayHabits = habits
                        .where((h) => h.isScheduledForWeekday(selectedDate.weekday))
                        .toList();
                    return Text(
                      '${todayHabits.length} thói quen',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),
        ),

        // 3. Habit List
        habitsAsync.when(
          data: (allHabits) {
            // Filter habits scheduled for selected weekday
            final scheduledHabits = allHabits
                .where((h) => h.isScheduledForWeekday(selectedDate.weekday))
                .toList();

            if (scheduledHabits.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 72,
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không có thói quen nào hôm nay',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhấn nút "Thêm thói quen" bên dưới để bắt đầu rèn luyện kỷ luật!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final completions = completionsAsync.value ?? {};

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final habit = scheduledHabits[index];
                  final isCompleted = completions[habit.id] ?? false;
                  return HabitTile(
                    habit: habit,
                    isCompleted: isCompleted,
                  );
                },
                childCount: scheduledHabits.length,
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => SliverFillRemaining(
            child: Center(
              child: Text('Lỗi khi tải dữ liệu: $err'),
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 90), // Bottom padding for FAB
        ),
      ],
    );
  }
}

