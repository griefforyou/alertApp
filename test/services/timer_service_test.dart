import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models/session_state.dart';
import 'package:study_timer/models/study_preset.dart';
import 'package:study_timer/services/timer_service.dart';
import 'package:study_timer/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class MockPathProvider extends PathProviderPlatform {
  static final Directory _tempDir = Directory.systemTemp.createTempSync('test_timer_');

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _tempDir.path;
  }
}

void main() {
  late TimerService timerService;
  late StorageService storageService;

  setUp(() {
    PathProviderPlatform.instance = MockPathProvider();
    storageService = StorageService();
    timerService = TimerService(storageService);
  });

  tearDown(() async {
    timerService.dispose();
    // Clean up any leftover session file
    final dir = MockPathProvider._tempDir.absolute;
    final file = File('${dir.path}/current_session.json');
    if (await file.exists()) {
      await file.delete();
    }
  });

  group('start', () {
    test('creates session in learning phase', () async {
      final preset = StudyPreset(
        id: 'test', name: 'Test',
        studyMinutes: 45, breakMinutes: 10, totalCycles: 4,
      );

      await timerService.start(preset);

      expect(timerService.state, isNotNull);
      expect(timerService.state!.currentPhase, Phase.learning);
      expect(timerService.state!.currentCycle, 1);
      expect(timerService.remaining!.inMinutes, 45);
    });

    test('isRunning returns true after start', () async {
      final preset = StudyPreset(
        id: 'test', name: 'Test',
        studyMinutes: 25, breakMinutes: 5, totalCycles: 4,
      );

      await timerService.start(preset);
      expect(timerService.isRunning, true);
    });
  });

  group('pause and resume', () {
    test('pause sets isPaused', () async {
      final preset = StudyPreset(
        id: 'test', name: 'Test',
        studyMinutes: 25, breakMinutes: 5, totalCycles: 4,
      );

      await timerService.start(preset);
      timerService.pause();

      expect(timerService.state!.isPaused, true);
    });

    test('resume clears isPaused', () async {
      final preset = StudyPreset(
        id: 'test', name: 'Test',
        studyMinutes: 25, breakMinutes: 5, totalCycles: 4,
      );

      await timerService.start(preset);
      timerService.pause();
      timerService.resume();

      expect(timerService.state!.isPaused, false);
    });
  });

  group('stop', () {
    test('clears state and stops timer', () async {
      final preset = StudyPreset(
        id: 'test', name: 'Test',
        studyMinutes: 25, breakMinutes: 5, totalCycles: 4,
      );

      await timerService.start(preset);
      await timerService.stop();

      expect(timerService.state, isNull);
      expect(timerService.remaining, isNull);
      expect(timerService.isRunning, false);
    });
  });

  group('progress', () {
    test('returns 0.0 before start', () {
      expect(timerService.progress, 0.0);
    });
  });

  group('restoreFromStorage', () {
    test('restores nothing when no saved session', () async {
      await timerService.restoreFromStorage();
      expect(timerService.state, isNull);
    });
  });
}
