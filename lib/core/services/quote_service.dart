import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class QuoteData {
  final String quote;
  final String author;
  final String? enQuote;

  const QuoteData({
    required this.quote,
    required this.author,
    this.enQuote,
  });

  factory QuoteData.fromJson(Map<String, dynamic> json) {
    return QuoteData(
      quote: json['quote'] as String? ?? 'Kỷ luật là tự do.',
      author: json['author'] as String? ?? 'Jocko Willink',
      enQuote: json['enQuote'] as String?,
    );
  }
}

class QuoteService {
  static final QuoteService instance = QuoteService._init();
  QuoteService._init();

  // Cloudflare Worker URL (can be customized by user or environment variable)
  String workerBaseUrl = 'https://habit-tracker-worker.workers.dev';

  // Offline fallback quotes
  static const List<QuoteData> _fallbackQuotes = [
    QuoteData(
      quote: 'Kỷ luật là cầu nối giữa mục tiêu và thành tựu.',
      author: 'Jim Rohn',
      enQuote: 'Discipline is the bridge between goals and accomplishment.',
    ),
    QuoteData(
      quote: 'Mỗi ngày tiến bộ 1% sẽ tạo ra thay đổi khổng lồ sau một năm.',
      author: 'James Clear (Atomic Habits)',
      enQuote: '1% better every day compounds into remarkable results.',
    ),
    QuoteData(
      quote: 'Chúng ta là những gì chúng ta lặp lại. Sự xuất sắc là một thói quen.',
      author: 'Aristotle',
      enQuote: 'We are what we repeatedly do. Excellence is a habit.',
    ),
    QuoteData(
      quote: 'Động lực giúp bạn bắt đầu. Kỷ luật giúp bạn duy trì.',
      author: 'Jim Ryun',
      enQuote: 'Motivation gets you going, but discipline keeps you growing.',
    ),
  ];

  Future<QuoteData> getDailyQuote() async {
    try {
      final uri = Uri.parse('$workerBaseUrl/api/quote-and-verify');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['data'] != null) {
          return QuoteData.fromJson(data['data']['quote']);
        }
      }
    } catch (e) {
      debugPrint('[QuoteService] Offline or worker unreachable: $e');
    }

    // Pick offline quote based on day-of-year
    final now = DateTime.now();
    final dayOfYear = int.parse("${now.difference(DateTime(now.year, 1, 1)).inDays}");
    return _fallbackQuotes[dayOfYear % _fallbackQuotes.length];
  }

  Future<int?> verifyStreakOnCloudflare({
    required String habitId,
    required List<String> completedDates,
  }) async {
    try {
      final uri = Uri.parse('$workerBaseUrl/api/quote-and-verify');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'habitId': habitId,
          'completedDates': completedDates,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['data'] != null) {
          return (data['data']['verifiedStreak'] as num?)?.toInt();
        }
      }
    } catch (e) {
      debugPrint('[QuoteService] Cloudflare verification offline fallback: $e');
    }
    return null;
  }
}

