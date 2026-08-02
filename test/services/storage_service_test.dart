import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models/session_state.dart';
import 'package:study_timer/models/round_config.dart';
import 'package:study_timer/models/daily_record.dart';
import 'package:study_timer/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class MockPathProvider extends PathProviderPlatform {
  static final Directory _tempDir = Directory.systemTemp.createTempSync('test_storage_');

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _tempDir.path;
  }
}

void main() {
  late StorageService storage;
  late PathProviderPlatform original;

  setUp(() {
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = MockPathProvider();
    storage = StorageService();
  });

  tearDown(() {
    PathProviderPlatform.instance = original;
  });

  test('save and load session', () async {
    final session = SessionState(
      startTime: DateTime(2026, 7, 19, 20, 0),
      rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
      roundIndex: 0,
      multiCycle: true,
      totalCycles: 4,
      currentCycle: 1,
      currentPhase: Phase.learning,
      phaseStartTime: DateTime(2026, 7, 19, 20, 0),
    );

    await storage.saveSession(session);
    final loaded = await storage.loadSession();

    expect(loaded, isNotNull);
    expect(loaded!.studyMinutes, 45);
    expect(loaded.currentPhase, Phase.learning);
  });

  test('clear session removes file', () async {
    final session = SessionState(
      startTime: DateTime(2026, 7, 19, 20, 0),
      rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
      roundIndex: 0,
      multiCycle: true,
      totalCycles: 4,
      currentCycle: 1,
      currentPhase: Phase.learning,
      phaseStartTime: DateTime(2026, 7, 19, 20, 0),
    );

    await storage.saveSession(session);
    await storage.clearSession();
    final loaded = await storage.loadSession();

    expect(loaded, isNull);
  });

  test('loadSession returns null when no file exists', () async {
    final result = await storage.loadSession();
    expect(result, isNull);
  });

  test('loadSession returns null on corrupted file', () async {
    final dir = Directory.systemTemp.createTempSync('test_corrupt_');
    final mock = MockPathProvider();
    PathProviderPlatform.instance = mock;
    final file = File('${dir.path}/current_session.json');
    await file.writeAsString('not valid json');
    final result = await storage.loadSession();
    expect(result, isNull);
  });

  test('save and load today record', () async {
    final now = DateTime.now();
    final record = DailyRecord(
      date: DateTime(now.year, now.month, now.day),
      perTypeStats: {
        'study': const PerTypeStats(totalStudySeconds: 2700, completedCycles: 1),
      },
    );

    await storage.saveTodayRecord(record);
    final loaded = await storage.loadTodayRecord();

    expect(loaded, isNotNull);
    expect(loaded!.totalStudySeconds, 2700);
    expect(loaded.completedCycles, 1);
  });
}
