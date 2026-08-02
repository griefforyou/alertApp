import "dart:async";
import "package:flutter/foundation.dart";
import "../models/session_state.dart";
import "../models/timer_profile.dart";
import "storage_service.dart";
import "foreground_service.dart";

class StudyPhaseCompleted {
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;

  const StudyPhaseCompleted({
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
  });
}

class TimerService extends ChangeNotifier {
  final StorageService _storage;

  TimerService(this._storage);

  SessionState? _state;
  SessionState? get state => _state;

  Timer? _tickTimer;

  Duration? _remaining;
  Duration? get remaining => _remaining;

  double get progress {
    if (_state == null || _remaining == null) return 0.0;
    final total = Duration(
      minutes: _state!.currentPhase == Phase.learning
          ? _state!.studyMinutes
          : _state!.breakMinutes,
    );
    if (total.inSeconds <= 0) return 0.0;
    return 1.0 - (_remaining!.inSeconds / total.inSeconds);
  }

  bool get isRunning => _tickTimer != null;

  bool get isFinished => _state?.currentPhase == Phase.finished;

  static const _backgroundCatchUpThreshold = Duration(seconds: 3);
  bool _lastTransitionFromBackground = false;
  bool get lastTransitionFromBackground => _lastTransitionFromBackground;

  VoidCallback? onPhaseChanged;
  void Function(StudyPhaseCompleted)? onStudyPhaseCompleted;

  Future<void> start(TimerProfile profile) async {
    _lastTransitionFromBackground = false;
    final now = DateTime.now();
    _state = SessionState(
      startTime: now,
      profileId: profile.id,
      rounds: List.from(profile.rounds),
      roundIndex: 0,
      multiCycle: profile.multiCycle,
      totalCycles: profile.totalCycles,
      currentCycle: 1,
      currentPhase: Phase.learning,
      phaseStartTime: now,
    );
    _remaining = Duration(minutes: profile.rounds[0].workMinutes);
    await _storage.saveSession(_state!);
    _startTick();
    ForegroundService.instance.start();
    notifyListeners();
  }

  void _startTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _tick() {
    if (_state == null || _state!.isPaused || _state!.currentPhase == Phase.finished) return;
    final elapsed = DateTime.now().difference(_state!.phaseStartTime);
    final phaseDuration = Duration(
      minutes: _state!.currentPhase == Phase.learning
          ? _state!.studyMinutes
          : _state!.breakMinutes,
    );
    final remaining = phaseDuration - elapsed;
    _remaining = remaining < Duration.zero ? Duration.zero : remaining;
    if (_remaining!.inSeconds <= 0) {
      // 阶段结束时刻明显早于当前（App 挂起期间结束），属于后台补时过渡。
      // 后台时 iOS 已由定时通知提醒过，应用层应静默推进，避免切回前台重复响铃。
      _lastTransitionFromBackground =
          -remaining > _backgroundCatchUpThreshold;
      _advancePhase();
    }
    notifyListeners();
  }

  void _advancePhase() {
    if (_state == null || _state!.currentPhase == Phase.finished) return;

    if (_state!.currentPhase == Phase.learning) {
      final s = _state!;
      final isLastRound = s.roundIndex >= s.rounds.length - 1;
      final isLastCycle = s.totalCycles > 0 && s.currentCycle >= s.totalCycles;
      final hasNextLearning =
          !isLastRound || (s.multiCycle && !isLastCycle);

      if (hasNextLearning) {
        final now = DateTime.now();
        _state = s.copyWith(
          currentPhase: Phase.breaking,
          phaseStartTime: now,
        );
        _remaining = Duration(minutes: _state!.breakMinutes);
        _emitStudyPhaseCompleted(s, now);
      } else {
        final now = DateTime.now();
        _state = s.copyWith(currentPhase: Phase.finished);
        _tickTimer?.cancel();
        _tickTimer = null;
        _storage.clearSession();
        _emitStudyPhaseCompleted(s, now);
      }
    } else if (_state!.currentPhase == Phase.breaking) {
      final s = _state!;
      final nextRoundIdx = s.roundIndex + 1;

      if (nextRoundIdx >= s.rounds.length) {
        if (s.multiCycle) {
          final nextCycle = s.currentCycle + 1;
          if (s.totalCycles > 0 && nextCycle > s.totalCycles) {
            _state = s.copyWith(currentPhase: Phase.finished);
            _tickTimer?.cancel();
            _tickTimer = null;
            _storage.clearSession();
          } else {
            _state = s.copyWith(
              roundIndex: 0,
              currentCycle: nextCycle,
              currentPhase: Phase.learning,
              phaseStartTime: DateTime.now(),
            );
            _remaining = Duration(minutes: _state!.studyMinutes);
          }
        } else {
          _state = s.copyWith(currentPhase: Phase.finished);
          _tickTimer?.cancel();
          _tickTimer = null;
          _storage.clearSession();
        }
      } else {
        _state = s.copyWith(
          roundIndex: nextRoundIdx,
          currentPhase: Phase.learning,
          phaseStartTime: DateTime.now(),
        );
        _remaining = Duration(minutes: _state!.studyMinutes);
      }
    }

    onPhaseChanged?.call();
    if (_state != null && _state!.currentPhase != Phase.finished) {
      _storage.saveSession(_state!);
    } else {
      ForegroundService.instance.stop();
    }
    notifyListeners();
  }

  void _emitStudyPhaseCompleted(SessionState s, DateTime endTime) {
    final cb = onStudyPhaseCompleted;
    if (cb == null) return;
    cb(StudyPhaseCompleted(
      startTime: s.phaseStartTime,
      endTime: endTime,
      durationSeconds: s.studyMinutes * 60,
    ));
  }

  void pause() {
    if (_state == null || _state!.isPaused) return;
    _state = _state!.copyWith(isPaused: true, elapsedBeforePause: _remaining);
    _storage.saveSession(_state!);
    notifyListeners();
  }

  void resume() {
    if (_state == null || !_state!.isPaused) return;
    _remaining = _state!.elapsedBeforePause;
    final phaseDuration = Duration(
      minutes: _state!.currentPhase == Phase.learning
          ? _state!.studyMinutes
          : _state!.breakMinutes,
    );
    final elapsed = phaseDuration - _remaining!;
    _state = _state!.copyWith(
      isPaused: false,
      phaseStartTime: DateTime.now().subtract(elapsed),
    );
    _startTick();
    _storage.saveSession(_state!);
    notifyListeners();
  }

  Future<void> stop() async {
    _tickTimer?.cancel();
    _tickTimer = null;
    ForegroundService.instance.stop();
    _state = null;
    _remaining = null;
    await _storage.clearSession();
    notifyListeners();
  }

  Future<void> restoreFromStorage() async {
    final saved = await _storage.loadSession();
    if (saved == null) return;

    _state = saved;

    if (saved.isPaused) {
      _remaining = saved.elapsedBeforePause;
      notifyListeners();
      return;
    }

    if (saved.currentPhase == Phase.finished) {
      _remaining = Duration.zero;
      notifyListeners();
      return;
    }

    final elapsed = DateTime.now().difference(saved.phaseStartTime);
    final phaseDuration = Duration(
      minutes: saved.currentPhase == Phase.learning
          ? saved.studyMinutes
          : saved.breakMinutes,
    );
    final remaining = phaseDuration - elapsed;

    if (remaining.inSeconds <= 0) {
      _remaining = Duration.zero;
      final cb = onPhaseChanged;
      onPhaseChanged = null;
      _advancePhase();
      onPhaseChanged = cb;
    } else {
      _remaining = remaining;
    }

    // 若补时推进恰好到达 finished（后台期间全部轮次完成），不再启动 tick 计时器，
    // 否则已完成的会话会被每秒反复触发 _advancePhase -> onPhaseChanged，导致
    // “全部完成”弹窗在确认后不断重新弹出。
    if (_state!.currentPhase != Phase.finished) {
      _startTick();
      ForegroundService.instance.start();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}
