import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage_io.dart';
import '../models/session_state.dart';
import '../models/daily_record.dart';
import '../models/timer_profile.dart';

const _defaultNotificationSoundUri = 'default';

class StorageService {
  static const _sessionFile = 'current_session.json';
  static const _todayRecordFile = 'today_record.json';
  static const _profilesFile = 'timer_profiles.json';
  static const _themeModeFile = 'theme_mode.json';
  static const _notificationSoundFile = 'notification_sound.json';

  final StorageIO _io = StorageIO();

  Future<SessionState?> loadSession() async {
    try {
      final json = await _io.readString(_sessionFile);
      if (json == null) return null;
      return SessionState.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to load session: $e');
      return null;
    }
  }

  Future<void> saveSession(SessionState session) async {
    try {
      await _io.writeString(_sessionFile, jsonEncode(session.toJson()));
    } catch (e) {
      debugPrint('Failed to save session: $e');
    }
  }

  Future<void> clearSession() async {
    await _io.delete(_sessionFile);
  }

  Future<DailyRecord?> loadTodayRecord() async {
    try {
      final json = await _io.readString(_todayRecordFile);
      if (json == null) return null;
      return DailyRecord.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to load today record: $e');
      return null;
    }
  }

  Future<void> saveTodayRecord(DailyRecord record) async {
    try {
      await _io.writeString(_todayRecordFile, jsonEncode(record.toJson()));
    } catch (e) {
      debugPrint('Failed to save today record: $e');
    }
  }

  Future<void> clearTodayRecord() async {
    await _io.delete(_todayRecordFile);
  }

  Future<List<TimerProfile>> loadProfiles() async {
    try {
      final json = await _io.readString(_profilesFile);
      if (json == null) return TimerProfile.defaults();
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => TimerProfile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Failed to load profiles: $e');
      return TimerProfile.defaults();
    }
  }

  Future<void> saveProfiles(List<TimerProfile> profiles) async {
    try {
      await _io.writeString(_profilesFile, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    } catch (e) {
      debugPrint('Failed to save profiles: $e');
    }
  }

  Future<String> loadThemeMode() async {
    try {
      final json = await _io.readString(_themeModeFile);
      if (json == null) return 'system';
      return (jsonDecode(json) as Map<String, dynamic>)['mode'] as String? ?? 'system';
    } catch (e) {
      debugPrint('Failed to load theme mode: $e');
      return 'system';
    }
  }

  Future<void> saveThemeMode(String mode) async {
    try {
      await _io.writeString(_themeModeFile, jsonEncode({'mode': mode}));
    } catch (e) {
      debugPrint('Failed to save theme mode: $e');
    }
  }

  Future<String> loadNotificationSoundUri() async {
    try {
      final json = await _io.readString(_notificationSoundFile);
      if (json == null) return _defaultNotificationSoundUri;
      return (jsonDecode(json) as Map<String, dynamic>)['uri'] as String? ?? _defaultNotificationSoundUri;
    } catch (e) {
      debugPrint('Failed to load notification sound: $e');
      return _defaultNotificationSoundUri;
    }
  }

  Future<void> saveNotificationSoundUri(String uri) async {
    try {
      await _io.writeString(_notificationSoundFile, jsonEncode({'uri': uri}));
    } catch (e) {
      debugPrint('Failed to save notification sound: $e');
    }
  }
}
