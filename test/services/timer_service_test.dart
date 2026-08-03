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
    test('advances phase during restore and fires a single callback', () async {
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
      // 学习 45 分钟在 50 分钟前开始并已结束，休息随之进行了约 5 分钟，
      // 因此恢复时休息剩余约 5 分钟，而不是重置回完整 10 分钟。
      expect(timerService.remaining!.inSeconds, inInclusiveRange(299, 300));
      // 恢复时向 UI 暴露最终过渡，只触发一次回调。
      expect(callbackCount, 1);
    });

    test('restore reaching finished does not start tick loop', () async {
      final now = DateTime.now();
      await storageService.saveSession(SessionState(
        startTime: now.subtract(const Duration(minutes: 50)),
        rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
        roundIndex: 0,multiCycle: false,
    
        totalCycles: 1,
        currentCycle: 1,
        currentPhase: Phase.learning,
        phaseStartTime: now.subtract(const Duration(minutes: 50)),
      ));

      int callbackCount = 0;
      timerService.onPhaseChanged = () { callbackCount++; };

      await timerService.restoreFromStorage();

      expect(timerService.state!.currentPhase, Phase.finished);
      expect(timerService.isRunning, false);
      expect(timerService.remaining!.inSeconds, 0);
      expect(callbackCount, 1);
    });
  });

  group('background catch-up', () {
    test('advances through learning and break that both elapsed in background', () async {
      final now = DateTime.now();
      await storageService.saveSession(SessionState(
        startTime: now.subtract(const Duration(minutes: 60)),
        rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
        roundIndex: 0,
        multiCycle: true,
        totalCycles: 4,
        currentCycle: 1,
        currentPhase: Phase.learning,
        phaseStartTime: now.subtract(const Duration(minutes: 60)),
      ));

      await timerService.restoreFromStorage();

      // 学习 45 分钟 + 休息 10 分钟都已在后台结束：
      // 第 1 轮学习于 t=45m 结束、休息于 t=55m 结束，恢复时已进入第 2 轮学习 5 分钟，
      // 剩余约 40 分钟，而不是重新从休息的 10 分钟倒计时。
      expect(timerService.state!.currentPhase, Phase.learning);
      expect(timerService.state!.roundIndex, 0);
      expect(timerService.state!.currentCycle, 2);
      expect(timerService.remaining!.inSeconds, inInclusiveRange(2399, 2400));
      expect(timerService.isRunning, true);
    });

    test('restore catch-up into next learning pauses for confirmation', () async {
      final now = DateTime.now();
      await storageService.saveSession(SessionState(
        startTime: now.subtract(const Duration(minutes: 60)),
        rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
        roundIndex: 0,
        multiCycle: true,
        totalCycles: 4,
        currentCycle: 1,
        currentPhase: Phase.learning,
        phaseStartTime: now.subtract(const Duration(minutes: 60)),
      ));

      await timerService.restoreFromStorage();

      // 学习 + 休息都已在后台结束，恢复后进入第 2 轮学习，但必须暂停等待
      // 用户点击“知道了”确认，而不是自动开始倒计时。
      expect(timerService.state!.currentPhase, Phase.learning);
      expect(timerService.state!.isPaused, true);
      expect(timerService.remaining!.inSeconds, inInclusiveRange(2399, 2400));
    });

    test('emits study-phase-completed for each round finished in background', () async {
      final now = DateTime.now();
      await storageService.saveSession(SessionState(
        startTime: now.subtract(const Duration(minutes: 60)),
        rounds: [const RoundConfig(workMinutes: 45, breakMinutes: 10)],
        roundIndex: 0,
        multiCycle: true,
        totalCycles: 4,
        currentCycle: 1,
        currentPhase: Phase.learning,
        phaseStartTime: now.subtract(const Duration(minutes: 60)),
      ));

      int completed = 0;
      timerService.onStudyPhaseCompleted = (_) { completed++; };

      await timerService.restoreFromStorage();

      expect(completed, 1);
    });

    test('tick path advances through learning and break elapsed while suspended', () async {
      final profile = _profile(studyMinutes: 5, breakMinutes: 1, totalCycles: 4);
      await timerService.start(profile);

      int callbacks = 0;
      timerService.onPhaseChanged = () { callbacks++; };

      // 模拟锁屏/后台挂起 6 分钟：学习 5 分钟 + 休息 1 分钟都在后台结束。
      timerService.simulateBackgroundCatchUp(const Duration(minutes: 6));

      expect(timerService.lastTransitionFromBackground, true);
      expect(timerService.state!.currentPhase, Phase.learning);
      expect(timerService.state!.currentCycle, 2);
      // 刚进入第 2 轮学习，剩余约 5 分钟（而非重新从休息 1 分钟倒计时），
      // 且必须暂停等待“知道了”确认后再开始。
      expect(timerService.state!.isPaused, true);
      expect(timerService.remaining!.inSeconds, inInclusiveRange(299, 300));
      // 多阶段连续补时只触发一次 UI 回调（最终阶段）。
      expect(callbacks, 1);
    });

    test('transition within threshold is treated as foreground', () async {
      final profile = _profile(studyMinutes: 5, breakMinutes: 1);
      await timerService.start(profile);

      // 学习结束点刚过 1 秒，属于前台正常过渡，不视为后台补时。
      timerService.simulateBackgroundCatchUp(const Duration(seconds: 301));

      expect(timerService.lastTransitionFromBackground, false);
      expect(timerService.state!.currentPhase, Phase.breaking);
      expect(timerService.remaining!.inSeconds, inInclusiveRange(58, 60));
    });

    test('catch-up reaching finished stops the timer', () async {
      final profile = TimerProfile(
        id: 'test',
        category: TimerCategory.custom,
        customName: 'Test',
        rounds: [const RoundConfig(workMinutes: 5, breakMinutes: 1)],
        multiCycle: false,
        totalCycles: 1,
      );
      await timerService.start(profile);

      // 后台挂起 12 分钟：学习 5 分钟 + 休息 1 分钟全部结束 → 全部完成。
      timerService.simulateBackgroundCatchUp(const Duration(minutes: 12));

      expect(timerService.state!.currentPhase, Phase.finished);
      expect(timerService.isRunning, false);
      expect(timerService.remaining!.inSeconds, 0);
    });
  });
}
