import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session_state.dart';
import '../models/daily_record.dart';
import '../models/timer_profile.dart';

class StorageService {
  static const _sessionFile = 'current_session.json';
  static const _todayRecordFile = 'today_record.json';
  static const _profilesFile = 'timer_profiles.json';

  Future<Directory> get _storageDir => getApplicationDocumentsDirectory();

  Future<SessionState?> loadSession() async {
    try {
      final dir = await _storageDir;
      final file = File('${dir.path}/$_sessionFile');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SessionState.fromJson(json);
    } catch (e) {
      debugPrint('Failed to load session: $e');
      return null;
    }
  }

  Future<void> saveSession(SessionState session) async {
    try {
      final dir = await _storageDir;
      final file = File('${dir.path}/$_sessionFile');
      await file.writeAsString(jsonEncode(session.toJson()));
    } catch (e) {
      debugPrint('Failed to save session: $e');
    }
  }

  Future<void> clearSession() async {
    final dir = await _storageDir;
    final file = File('${dir.path}/$_sessionFile');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<DailyRecord?> loadTodayRecord() async {
    try {
      final dir = await _storageDir;
      final file = File('${dir.path}/$_todayRecordFile');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return DailyRecord.fromJson(json);
    } catch (e) {
      debugPrint('Failed to load today record: $e');
      return null;
    }
  }

  Future<void> saveTodayRecord(DailyRecord record) async {
    try {
      final dir = await _storageDir;
      final file = File('${dir.path}/$_todayRecordFile');
      await file.writeAsString(jsonEncode(record.toJson()));
    } catch (e) {
      debugPrint('Failed to save today record: $e');
    }
  }

  Future<void> clearTodayRecord() async {
    final dir = await _storageDir;
    final file = File('${dir.path}/$_todayRecordFile');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<TimerProfile>> loadProfiles() async {
    try {
      final dir = await _storageDir;
      final file = File('${dir.path}/$_profilesFile');
      if (!await file.exists()) return TimerProfile.defaults();
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list.map((e) => TimerProfile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Failed to load profiles: $e');
      return TimerProfile.defaults();
    }
  }

  Future<void> saveProfiles(List<TimerProfile> profiles) async {
    try {
      final dir = await _storageDir;
      final file = File('${dir.path}/$_profilesFile');
      await file.writeAsString(jsonEncode(profiles.map((p) => p.toJson()).toList()));
    } catch (e) {
      debugPrint('Failed to save profiles: $e');
    }
  }
}
