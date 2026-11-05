import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/habit_provider.dart';

class DailyProgressCard extends ConsumerWidget {
  const DailyProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = ref.watch(selectedDateStringProvider);
    final statsAsync = ref.watch(dailyStatsProvider(dateStr));
    final quoteAsync = ref.watch(dailyQuoteProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E2DE2).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Progress info + Circular Progress
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tiến Độ Hôm Nay',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    statsAsync.when(
                      data: (stats) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${stats.completed}/${stats.total} hoàn thành',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stats.total == 0
                                  ? 'Chưa có thói quen nào hôm nay'
                                  : stats.percentage >= 100
                                      ? '🎉 Xuất sắc! Bạn đã hoàn thành 100%'
                                      : 'Đạt ${stats.percentage.toStringAsFixed(0)}% mục tiêu ngày',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Text(
                        'Đang tải...',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      error: (_, __) => const Text(
                        '0/0 hoàn thành',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Circular Progress Indicator
              statsAsync.when(
                data: (stats) {
                  final progress = stats.total > 0 ? (stats.completed / stats.total) : 0.0;
                  return SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),

          // Motivational Quote from Cloudflare Worker
          quoteAsync.when(
            data: (quote) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${quote.quote}"',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '— ${quote.author}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Text(
              'Đang tải câu nói truyền cảm hứng...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}

