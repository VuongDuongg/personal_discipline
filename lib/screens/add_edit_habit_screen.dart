import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/notification_service.dart';
import '../core/services/sync_service.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';

class AddEditHabitScreen extends ConsumerStatefulWidget {
  final Habit? habit;

  const AddEditHabitScreen({super.key, this.habit});

  @override
  ConsumerState<AddEditHabitScreen> createState() => _AddEditHabitScreenState();
}

class _AddEditHabitScreenState extends ConsumerState<AddEditHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;

  // Curated color options
  static const List<String> _colorOptions = [
    '#2196F3', // Blue
    '#4CAF50', // Green
    '#FF9800', // Orange
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#009688', // Teal
    '#F44336', // Red
    '#3F51B5', // Indigo
    '#00BCD4', // Cyan
    '#FFC107', // Amber
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  // Curated habit icons
  static const List<IconData> _iconOptions = [
    Icons.fitness_center,
    Icons.menu_book,
    Icons.local_drink,
    Icons.directions_run,
    Icons.self_improvement,
    Icons.bedtime,
    Icons.code,
    Icons.payments,
    Icons.brush,
    Icons.music_note,
    Icons.timer,
    Icons.sports_soccer,
    Icons.restaurant,
    Icons.emoji_events,
    Icons.cleaning_services,
    Icons.spa,
  ];

  late String _selectedColorHex;
  late int _selectedIconCode;
  late Set<int> _selectedDays; // 1=Mon ... 7=Sun
  TimeOfDay? _reminderTime;

  bool get isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _titleController = TextEditingController(text: h?.title ?? '');
    _descController = TextEditingController(text: h?.description ?? '');

    _selectedColorHex = h?.colorHex ?? _colorOptions.first;
    _selectedIconCode = h?.iconCode ?? _iconOptions.first.codePoint;
    _selectedDays = (h != null)
        ? h.parsedFrequencyDays.toSet()
        : {1, 2, 3, 4, 5, 6, 7};

    if (h?.reminderTime != null && h!.reminderTime!.isNotEmpty) {
      final parts = h.reminderTime!.split(':');
      if (parts.length == 2) {
        _reminderTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 7,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 7, minute: 0),
      helpText: 'CHỌN GIỜ NHẮC NHỞ HÀNG NGÀY',
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  void _saveHabit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất 1 ngày lặp lại trong tuần!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reminderStr = _reminderTime != null
        ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
        : null;

    final sortedDays = _selectedDays.toList()..sort();
    final frequencyDaysJson = jsonEncode(sortedDays);

    final notifier = ref.read(habitListNotifierProvider.notifier);
    final userId = SyncService.instance.currentUserId;

    if (isEditing) {
      final updated = widget.habit!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        iconCode: _selectedIconCode,
        colorHex: _selectedColorHex,
        frequencyDays: frequencyDaysJson,
        reminderTime: reminderStr,
        userId: userId ?? widget.habit!.userId,
      );
      notifier.updateHabit(updated);
    } else {
      final newHabit = Habit(
        id: const Uuid().v4(),
        userId: userId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        iconCode: _selectedIconCode,
        colorHex: _selectedColorHex,
        frequencyDays: frequencyDaysJson,
        reminderTime: reminderStr,
        currentStreak: 0,
        createdAt: DateTime.now().toIso8601String(),
        isSynced: 0,
        isDeleted: 0,
      );
      notifier.addHabit(newHabit);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Đã cập nhật thói quen' : 'Đã tạo thói quen mới'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentColor = Color(int.parse('FF${_selectedColorHex.replaceFirst('#', '')}', radix: 16));

    final weekdayLabels = {
      1: 'Thứ 2',
      2: 'Thứ 3',
      3: 'Thứ 4',
      4: 'Thứ 5',
      5: 'Thứ 6',
      6: 'Thứ 7',
      7: 'Chủ Nhật',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa Thói quen' : 'Thêm Thói quen Mới'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 28),
            onPressed: _saveHabit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Preview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: currentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: currentColor.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      IconData(_selectedIconCode, fontFamily: 'MaterialIcons'),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleController.text.isEmpty
                              ? 'Tên thói quen của bạn'
                              : _titleController.text,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: currentColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _descController.text.isEmpty
                              ? 'Mô tả ngắn gọn...'
                              : _descController.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1. Title Input
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Tên thói quen *',
                hintText: 'Ví dụ: Đọc sách 20 trang, Chạy bộ 3km...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
              onChanged: (_) => setState(() {}),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập tên thói quen';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 2. Description Input
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: 'Mô tả (tùy chọn)',
                hintText: 'Ghi chú thêm về mục tiêu hoặc địa điểm thực hiện',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // 3. Icon Selection
            Text(
              'Chọn Biểu Tượng',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _iconOptions.length,
                itemBuilder: (context, index) {
                  final icon = _iconOptions[index];
                  final isSelected = icon.codePoint == _selectedIconCode;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIconCode = icon.codePoint),
                    child: Container(
                      width: 50,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? currentColor : theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? currentColor : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        size: 26,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 4. Color Selection
            Text(
              'Chọn Màu Sắc',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: _colorOptions.map((hex) {
                final isSelected = hex == _selectedColorHex;
                final col = Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorHex = hex),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black87 : Colors.transparent,
                        width: isSelected ? 3.0 : 0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: col.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 5. Frequency Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tần Suất Lặp Lại',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                PopupMenuButton<String>(
                  child: Text(
                    'Phím tắt ▾',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val == 'all') {
                        _selectedDays = {1, 2, 3, 4, 5, 6, 7};
                      } else if (val == 'weekdays') {
                        _selectedDays = {1, 2, 3, 4, 5};
                      } else if (val == 'weekend') {
                        _selectedDays = {6, 7};
                      }
                    });
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('Cả tuần (7 ngày)')),
                    PopupMenuItem(value: 'weekdays', child: Text('Ngày trong tuần (T2 - T6)')),
                    PopupMenuItem(value: 'weekend', child: Text('Cuối tuần (T7 - CN)')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isSelected = _selectedDays.contains(dayNum);
                return FilterChip(
                  label: Text(weekdayLabels[dayNum]!),
                  selected: isSelected,
                  selectedColor: currentColor.withOpacity(0.2),
                  checkmarkColor: currentColor,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? currentColor : null,
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(dayNum);
                      } else {
                        if (_selectedDays.length > 1) {
                          _selectedDays.remove(dayNum);
                        }
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),

            // 6. Reminder Time Picker
            Text(
              'Hẹn Giờ Nhắc Nhở',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListTile(
                leading: const Icon(Icons.alarm, color: Colors.blue, size: 28),
                title: Text(
                  _reminderTime != null
                      ? 'Nhắc nhở lúc: ${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                      : 'Không đặt giờ nhắc nhở',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Hẹn giờ báo thức cục bộ trên thiết bị'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_reminderTime != null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => setState(() => _reminderTime = null),
                        tooltip: 'Xóa giờ nhắc',
                      ),
                    ElevatedButton(
                      onPressed: _pickReminderTime,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_reminderTime == null ? 'Chọn giờ' : 'Đổi giờ'),
                    ),
                  ],
                ),
              ),
            ),
            if (_reminderTime != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await NotificationService.instance.showInstantNotification(
                    title: '🔔 Thông báo kiểm tra',
                    body: 'Thói quen "${_titleController.text.isEmpty ? "mới" : _titleController.text}": Nhắc nhở hoạt động bình thường!',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã gửi thông báo thử lên thanh trạng thái!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Thử gửi thông báo kiểm tra ngay'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 36),

            // Save Button
            FilledButton.icon(
              onPressed: _saveHabit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                isEditing ? 'LƯU THAY ĐỔI' : 'TẠO THÓI QUEN',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

