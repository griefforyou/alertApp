import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session_state.dart';
import '../models/daily_record.dart';

class StorageService {
  static const _sessionFile = 'current_session.json';
  static const _todayRecordFile = 'today_record.json';

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
    final dir = await _storageDir;
    final file = File('${dir.path}/$_sessionFile');
    await file.writeAsString(jsonEncode(session.toJson()));
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
    final dir = await _storageDir;
    final file = File('${dir.path}/$_todayRecordFile');
    await file.writeAsString(jsonEncode(record.toJson()));
  }
}
