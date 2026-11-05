class HabitLog {
  final String id;
  final String habitId;
  final String? userId;
  final String completedDate; // "YYYY-MM-DD"
  final int isCompleted; // 0: false, 1: true
  final int isSynced; // 0: false, 1: true

  const HabitLog({
    required this.id,
    required this.habitId,
    this.userId,
    required this.completedDate,
    this.isCompleted = 1,
    this.isSynced = 0,
  });

  bool get completed => isCompleted == 1;

  HabitLog copyWith({
    String? id,
    String? habitId,
    String? userId,
    String? completedDate,
    int? isCompleted,
    int? isSynced,
  }) {
    return HabitLog(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      userId: userId ?? this.userId,
      completedDate: completedDate ?? this.completedDate,
      isCompleted: isCompleted ?? this.isCompleted,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'user_id': userId,
      'completed_date': completedDate,
      'is_completed': isCompleted,
      'is_synced': isSynced,
    };
  }

  factory HabitLog.fromMap(Map<String, dynamic> map) {
    return HabitLog(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      userId: map['user_id'] as String?,
      completedDate: map['completed_date'] as String,
      isCompleted: ((map['is_completed'] as num?) ?? 1).toInt(),
      isSynced: ((map['is_synced'] as num?) ?? 0).toInt(),
    );
  }
}

