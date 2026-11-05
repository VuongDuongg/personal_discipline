import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static final SharedPreferencesService instance = SharedPreferencesService._init();
  SharedPreferences? _prefs;

  SharedPreferencesService._init();

  static const _keyDarkMode = 'is_dark_mode';
  static const _keyNotificationsEnabled = 'notifications_enabled';
  static const _keyLastSyncAt = 'last_sync_at';

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Dark/Light Mode
  bool get isDarkMode => _prefs?.getBool(_keyDarkMode) ?? false;

  Future<bool> setDarkMode(bool value) async {
    await init();
    return await _prefs!.setBool(_keyDarkMode, value);
  }

  // Notification Status
  bool get isNotificationEnabled => _prefs?.getBool(_keyNotificationsEnabled) ?? true;

  Future<bool> setNotificationEnabled(bool value) async {
    await init();
    return await _prefs!.setBool(_keyNotificationsEnabled, value);
  }

  // Last Sync Timestamp
  String? get lastSyncAt => _prefs?.getString(_keyLastSyncAt);

  Future<bool> setLastSyncAt(String iso8601Timestamp) async {
    await init();
    return await _prefs!.setString(_keyLastSyncAt, iso8601Timestamp);
  }
}

