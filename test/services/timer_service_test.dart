import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models/session_state.dart';
import 'package:study_timer/models/timer_profile.dart';
import 'package:study_timer/models/round_config.dart';
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

  tearDown(() {
    timerService.dispose();
  });

  TimerProfile _profile({int studyMinutes = 45, int breakMinutes = 10, int totalCycles = 4}) {
    return TimerProfile(
      id: 'test',
      category: TimerCategory.custom,
      customName: 'Test',
      rounds: [RoundConfig(workMinutes: studyMinutes, breakMinutes: breakMinutes)],
      multiCycle: true,
      totalCycles: totalCycles,
    );
  }

  group('start', () {
    test('creates session in learning phase', () async {
      final profile = _profile();

      await timerService.start(profile);

      expect(timerService.state, isNotNull);
      expect(timerService.state!.currentPhase, Phase.learning);
      expect(timerService.state!.currentCycle, 1);
      expect(timerService.remaining!.inMinutes, 45);
    });

    test('isRunning returns true after start', () async {
      final profile = _profile(studyMinutes: 25, breakMinutes: 5);

      await timerService.start(profile);
      expect(timerService.isRunning, true);
    });
  });

  group('pause and resume', () {
    test('pause sets isPaused', () async {
      final profile = _profile(studyMinutes: 25, breakMinutes: 5);

      await timerService.start(profile);
      timerService.pause();

      expect(timerService.state!.isPaused, true);
    });

    test('resume clears isPaused', () async {
      final profile = _profile(studyMinutes: 25, breakMinutes: 5);

      await timerService.start(profile);
      timerService.pause();
      timerService.resume();

      expect(timerService.state!.isPaused, false);
    });
  });

  group('stop', () {
    test('clears state and stops timer', () async {
      final profile = _profile(studyMinutes: 25, breakMinutes: 5);

      await timerService.start(profile);
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

    test('restores active learning session', () async {
      final now = DateTime.now();
      await storageService.saveSession(SessionState(
        startTime: now.subtract(const Duration(minutes: 10)),
        rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
        roundIndex: 0,multiCycle: true,
    
        totalCycles: 4,
        currentCycle: 1,
        currentPhase: Phase.learning,
        phaseStartTime: now.subtract(const Duration(minutes: 10)),
      ));

      final service = TimerService(storageService);
      await service.restoreFromStorage();

      expect(service.state, isNotNull);
      expect(service.state!.currentPhase, Phase.learning);
      expect(service.remaining!.inMinutes, greaterThanOrEqualTo(34)); // ~35, allow drift
      expect(service.isRunning, true);
      service.dispose();
    });

    test('restores finished session', () async {
      await storageService.saveSession(SessionState(
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
        roundIndex: 0,multiCycle: true,
    
        totalCycles: 4,
        currentCycle: 4,
        currentPhase: Phase.finished,
        phaseStartTime: DateTime.now(),
      ));

      final service = TimerService(storageService);
      await service.restoreFromStorage();

      expect(service.isFinished, true);
      expect(service.remaining!.inSeconds, 0);
      service.dispose();
    });

    test('restores paused session', () async {
      final now = DateTime.now();
      final pausedRemaining = const Duration(minutes: 30);
      await storageService.saveSession(SessionState(
        startTime: now.subtract(const Duration(minutes: 15)),
        rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
        roundIndex: 0,multiCycle: true,
    
        totalCycles: 4,
        currentCycle: 1,
        currentPhase: Phase.learning,
        phaseStartTime: now.subtract(const Duration(minutes: 15)),
        isPaused: true,
        elapsedBeforePause: pausedRemaining,
      ));

      final service = TimerService(storageService);
      await service.restoreFromStorage();

      expect(service.state, isNotNull);
      expect(service.state!.isPaused, true);
      expect(service.remaining!.inMinutes, 30);
      service.dispose();
    });
  });

  group('isFinished', () {
    test('returns false before start', () {
      expect(timerService.isFinished, false);
    });

    test('returns false after start', () async {
      await timerService.start(_profile());
      expect(timerService.isFinished, false);
    });

    test('returns true after restore of finished session', () async {
      await storageService.saveSession(SessionState(
        startTime: DateTime.now(),
        rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
        roundIndex: 0,multiCycle: true,
    
        totalCycles: 4,
        currentCycle: 4,
        currentPhase: Phase.finished,
        phaseStartTime: DateTime.now(),
      ));

      final service = TimerService(storageService);
      await service.restoreFromStorage();

      expect(service.isFinished, true);
      service.dispose();
    });
  });

  group('progress', () {
    test('returns 0.0 before start', () {
      expect(timerService.progress, 0.0);
    });

    test('returns 0.0 immediately after start', () async {
      await timerService.start(_profile());
      expect(timerService.progress, closeTo(0.0, 0.01));
    });
  });

  group('restore phase advance', () {
    test('advances phase during restore but does not fire callback', () async {
      final now = DateTime.now();
      await storageService.saveSession(SessionState(
        startTime: now.subtract(const Duration(minutes: 50)),
        rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
        roundIndex: 0,multiCycle: true,
    
        totalCycles: 4,
        currentCycle: 1,
        currentPhase: Phase.learning,
        phaseStartTime: now.subtract(const Duration(minutes: 50)),
      ));

      int callbackCount = 0;
      timerService.onPhaseChanged = () { callbackCount++; };

      await timerService.restoreFromStorage();

      expect(timerService.state!.currentPhase, Phase.breaking);
      expect(timerService.remaining!.inMinutes, 10);
      expect(callbackCount, 0);
    });
  });
}
