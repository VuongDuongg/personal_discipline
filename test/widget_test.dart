import 'package:flutter_test/flutter_test.dart';
import 'package:personal_discipline/models/habit.dart';

void main() {
  test('Habit model serialization and frequency test', () {
    final habit = Habit(
      id: 'test-1',
      title: 'Đọc sách',
      iconCode: 57448,
      colorHex: '#2196F3',
      frequencyDays: '[1,3,5]',
      createdAt: DateTime.now().toIso8601String(),
    );

    expect(habit.title, 'Đọc sách');
    expect(habit.isScheduledForWeekday(1), true); // Monday
    expect(habit.isScheduledForWeekday(2), false); // Tuesday
    expect(habit.isScheduledForWeekday(3), true); // Wednesday

    final map = habit.toMap();
    final fromMap = Habit.fromMap(map);
    expect(fromMap.id, habit.id);
    expect(fromMap.title, habit.title);
  });
}
