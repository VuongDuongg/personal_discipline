import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/habit.dart';
import '../../models/habit_log.dart';
import '../database/local_database.dart';
import 'shared_prefs_service.dart';

enum SyncResultStatus { success, notAuthenticated, networkError, error }

class SyncResult {
  final SyncResultStatus status;
  final String message;
  final int syncedHabitsCount;
  final int syncedLogsCount;

  SyncResult({
    required this.status,
    required this.message,
    this.syncedHabitsCount = 0,
    this.syncedLogsCount = 0,
  });
}

class SyncService {
  static final SyncService instance = SyncService._init();
  final LocalDatabase _localDb = LocalDatabase.instance;
  final SharedPreferencesService _prefs = SharedPreferencesService.instance;

  SyncService._init();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated {
    final client = _client;
    return client != null && client.auth.currentUser != null;
  }

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<SyncResult> syncData() async {
    final client = _client;
    if (client == null || !isAuthenticated) {
      return SyncResult(
        status: SyncResultStatus.notAuthenticated,
        message: 'Bạn chưa đăng nhập Supabase. Dữ liệu đang được lưu an toàn cục bộ trên thiết bị.',
      );
    }

    final userId = currentUserId!;

    try {
      // 1. Fetch unsynced local habits
      final unsyncedHabits = await _localDb.getUnsyncedHabits();
      int habitsSyncedCount = 0;

      if (unsyncedHabits.isNotEmpty) {
        final habitPayloads = unsyncedHabits.map((h) {
          final map = h.toMap();
          map['user_id'] = userId;
          map['is_synced'] = 1;
          return map;
        }).toList();

        // Upsert to Supabase 'habits' table
        await client.from('habits').upsert(habitPayloads);
        await _localDb.markHabitsAsSynced(unsyncedHabits.map((e) => e.id).toList());
        habitsSyncedCount = unsyncedHabits.length;
      }

      // 2. Fetch unsynced local logs
      final unsyncedLogs = await _localDb.getUnsyncedLogs();
      int logsSyncedCount = 0;

      if (unsyncedLogs.isNotEmpty) {
        final logPayloads = unsyncedLogs.map((l) {
          final map = l.toMap();
          map['user_id'] = userId;
          map['is_synced'] = 1;
          return map;
        }).toList();

        // Upsert to Supabase 'habit_logs' table
        await client.from('habit_logs').upsert(logPayloads);
        await _localDb.markLogsAsSynced(unsyncedLogs.map((e) => e.id).toList());
        logsSyncedCount = unsyncedLogs.length;
      }

      // 3. Optional: Pull cloud changes down to SQLite
      try {
        final remoteHabits = await client.from('habits').select().eq('user_id', userId);
        for (var row in remoteHabits) {
          final habit = Habit.fromMap(row);
          await _localDb.upsertHabitFromRemote(habit);
        }

        final remoteLogs = await client.from('habit_logs').select().eq('user_id', userId);
        for (var row in remoteLogs) {
          final log = HabitLog.fromMap(row);
          await _localDb.upsertLogFromRemote(log);
        }
      } catch (pullError) {
        debugPrint('[SyncService] Notice on pulling remote: $pullError');
      }

      // 4. Update last_sync_at in SharedPreferences
      final nowIso = DateTime.now().toIso8601String();
      await _prefs.setLastSyncAt(nowIso);

      return SyncResult(
        status: SyncResultStatus.success,
        message: 'Đồng bộ đám mây thành công!',
        syncedHabitsCount: habitsSyncedCount,
        syncedLogsCount: logsSyncedCount,
      );
    } catch (e) {
      debugPrint('[SyncService] Sync error: $e');
      return SyncResult(
        status: SyncResultStatus.networkError,
        message: 'Không thể kết nối máy chủ Supabase. Đã lưu trữ cục bộ đầy đủ.',
      );
    }
  }
}
