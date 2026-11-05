import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';
import '../providers/habit_provider.dart';
import '../providers/stats_provider.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPeriod = ref.watch(selectedStatsPeriodProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống Kê Tiến Độ', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // 1. SegmentedButton for switching [Ngày, Tuần, Tháng]
          Center(
            child: SegmentedButton<StatsPeriod>(
              segments: const [
                ButtonSegment<StatsPeriod>(
                  value: StatsPeriod.day,
                  label: Text('Ngày'),
                  icon: Icon(Icons.pie_chart_outline),
                ),
                ButtonSegment<StatsPeriod>(
                  value: StatsPeriod.week,
                  label: Text('Tuần'),
                  icon: Icon(Icons.bar_chart_outlined),
                ),
                ButtonSegment<StatsPeriod>(
                  value: StatsPeriod.month,
                  label: Text('Tháng'),
                  icon: Icon(Icons.show_chart_outlined),
                ),
              ],
              selected: {currentPeriod},
              onSelectionChanged: (newSelection) {
                ref.read(selectedStatsPeriodProvider.notifier).state = newSelection.first;
              },
            ),
          ),
          const SizedBox(height: 20),

          // 2. Dynamic Content depending on selected tab
          switch (currentPeriod) {
            StatsPeriod.day => const _DailyStatisticsView(),
            StatsPeriod.week => const _WeeklyStatisticsView(),
            StatsPeriod.month => const _MonthlyStatisticsView(),
          },
        ],
      ),
    );
  }
}

// ==============================================================================
// 1. TAB NGÀY: PIE CHART
// ==============================================================================
class _DailyStatisticsView extends ConsumerWidget {
  const _DailyStatisticsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = ref.watch(selectedDateStringProvider);
    final dailyStatsAsync = ref.watch(dailyStatsProvider(dateStr));
    final theme = Theme.of(context);

    return dailyStatsAsync.when(
      data: (stats) {
        final completed = stats.completed;
        final total = stats.total;
        final remaining = (total - completed).clamp(0, total);
        final pct = stats.percentage;

        return Column(
          children: [
            // Chart Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'Tỷ Lệ Hoàn Thành Ngày ($dateStr)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: total == 0
                          ? Center(
                              child: Text(
                                'Không có thói quen nào cần thực hiện trong ngày này',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                              ),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 4,
                                    centerSpaceRadius: 65,
                                    sections: [
                                      PieChartSectionData(
                                        value: completed.toDouble(),
                                        color: const Color(0xFF4CAF50),
                                        radius: 36,
                                        showTitle: false,
                                      ),
                                      if (remaining > 0)
                                        PieChartSectionData(
                                          value: remaining.toDouble(),
                                          color: Colors.grey.shade300,
                                          radius: 30,
                                          showTitle: false,
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${pct.toStringAsFixed(0)}%',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF4CAF50),
                                      ),
                                    ),
                                    Text(
                                      'Kỷ luật',
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(const Color(0xFF4CAF50), 'Đã hoàn thành ($completed)'),
                        const SizedBox(width: 20),
                        _buildLegendItem(Colors.grey.shade400, 'Chưa xong ($remaining)'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Summary Metrics Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Mục tiêu',
                    value: '$total',
                    icon: Icons.flag_outlined,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Đạt được',
                    value: '$completed',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Còn lại',
                    value: '$remaining',
                    icon: Icons.hourglass_empty,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ==============================================================================
// 2. TAB TUẦN: BAR CHART
// ==============================================================================
class _WeeklyStatisticsView extends ConsumerWidget {
  const _WeeklyStatisticsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyStatsAsync = ref.watch(weeklyStatsProvider);
    final theme = Theme.of(context);

    return weeklyStatsAsync.when(
      data: (data) {
        final days = data.days;
        int totalWeekCompletions = 0;
        int maxCompletions = 0;
        String bestDay = 'T2';

        for (var d in days) {
          totalWeekCompletions += d.completedCount;
          if (d.completedCount > maxCompletions) {
            maxCompletions = d.completedCount;
            bestDay = d.label;
          }
        }

        final double maxY = (maxCompletions < 5 ? 5 : maxCompletions + 2).toDouble();

        return Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoàn Thành Trong Tuần (Thứ 2 - Chủ Nhật)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'So sánh số lượng thói quen bạn đã hoàn thành mỗi ngày',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          maxY: maxY,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final d = days[group.x.toInt()];
                                return BarTooltipItem(
                                  '${d.label}: ${rod.toY.toInt()} thói quen',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (val, meta) {
                                  if (val % 2 == 0) {
                                    return Text(
                                      val.toInt().toString(),
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < days.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        days[idx].label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: days[idx].label == bestDay && maxCompletions > 0
                                              ? theme.colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 2,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.withOpacity(0.15),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(days.length, (i) {
                            final count = days[i].completedCount.toDouble();
                            final isBest = days[i].label == bestDay && count > 0;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: count,
                                  color: isBest ? const Color(0xFF8E2DE2) : const Color(0xFF2196F3),
                                  width: 18,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Highlight Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Tổng tuần này',
                    value: '$totalWeekCompletions',
                    icon: Icons.checklist_rtl,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Ngày tốt nhất',
                    value: maxCompletions > 0 ? '$bestDay ($maxCompletions)' : 'Chưa có',
                    icon: Icons.star_border,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
    );
  }
}

// ==============================================================================
// 3. TAB THÁNG: LINE CHART
// ==============================================================================
class _MonthlyStatisticsView extends ConsumerWidget {
  const _MonthlyStatisticsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyStatsAsync = ref.watch(monthlyStatsProvider);
    final theme = Theme.of(context);

    return monthlyStatsAsync.when(
      data: (data) {
        final points = data.trendPoints;
        final totalIn30Days = data.totalCompletionsIn30Days;
        final bestStreak = data.bestStreak;

        final spots = List.generate(points.length, (i) {
          return FlSpot(i.toDouble(), points[i].count.toDouble());
        });

        double maxY = 4;
        for (var p in points) {
          if (p.count > maxY) maxY = p.count.toDouble();
        }
        maxY += 1;

        final avgDaily = (totalIn30Days / 30.0).toStringAsFixed(1);

        return Column(
          children: [
            // Streak Highlight Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🔥', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chuỗi Kỷ Lục Dài Nhất',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$bestStreak ngày liên tiếp',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Line Chart Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xu Hướng Kỷ Luật 30 Ngày Gần Nhất',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Biểu đồ thể hiện sự kiên trì liên tục mỗi ngày',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 210,
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: maxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 2,
                            getDrawingHorizontalLine: (val) => FlLine(
                              color: Colors.grey.withOpacity(0.12),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (v, m) {
                                  if (v % 2 == 0) {
                                    return Text(
                                      v.toInt().toString(),
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 7,
                                getTitlesWidget: (val, meta) {
                                  final idx = val.toInt();
                                  if (idx >= 0 && idx < points.length) {
                                    final dStr = points[idx].dateStr;
                                    final parts = dStr.split('-');
                                    if (parts.length == 3) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Text(
                                          '${parts[2]}/${parts[1]}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: const Color(0xFF673AB7),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFF673AB7).withOpacity(0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Summary Metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Tổng 30 ngày',
                    value: '$totalIn30Days',
                    icon: Icons.done_all,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Trung bình/ngày',
                    value: avgDaily,
                    icon: Icons.trending_up,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
    );
  }
}

// Reusable Metric Card
Widget _buildMetricCard(
  BuildContext context, {
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: isDark ? theme.cardColor : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            Icon(icon, size: 18, color: color),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

