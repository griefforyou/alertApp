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

  /// 后台补时循环中暂停中间状态的持久化：仅在补时结束后一次性保存最终状态，
  /// 避免循环内多次未等待的并发写入同一文件导致 JSON 损坏。
  bool _savingPaused = false;

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
    final now = DateTime.now();
    final phaseDuration = _phaseDuration(_state!);
    final elapsed = now.difference(_state!.phaseStartTime);
    if (elapsed >= phaseDuration) {
      // 阶段结束时刻明显早于当前（App 挂起期间结束），属于后台补时过渡。
      // 后台时 iOS 已由定时通知提醒过，应用层应静默推进，避免切回前台重复响铃。
      _lastTransitionFromBackground =
          elapsed - phaseDuration > _backgroundCatchUpThreshold;
      if (_catchUpPhases(now, fireFinalCallback: true)) {
        // 补时推进后才需要持久化：一次性保存最终状态，避免循环内多次并发写。
        // 若补时已推进到 finished，_advancePhase 内已触发 clearSession 删除文件，
        // 这里不再重复写入，避免删除与写入并发争用同一文件（Windows 下 errno 32）。
        if (_state!.currentPhase != Phase.finished) {
          _storage.saveSession(_state!);
        }
      }
    } else {
      _remaining = phaseDuration - elapsed;
    }
    notifyListeners();
  }

  /// 后台补时：按墙钟时间连续推进所有已经完全流逝的阶段。
  ///
  /// 每个过渡使用上一阶段的真实结束时刻作为新阶段的 [phaseStartTime]，
  /// 而不是重置为“当前时间”，从而保留后台挂起期间流逝的休息/学习时间
  /// （例如学习 + 休息都在锁屏期间结束，切回前台不应让休息重新从 60 秒倒计时）。
  ///
  /// 多阶段补时只向 UI 暴露最终结果（最终一次 [onPhaseChanged]），避免在推进
  /// 循环中途弹出多个 overlay / 重复响铃 / 被页面里的 pause() 打断。
  /// 循环内暂停各中间状态的保存，持久化由调用方负责（_tick / restoreFromStorage
  /// 各做一次），避免循环内多次未等待的并发写入同一文件导致 JSON 损坏。
  bool _catchUpPhases(DateTime now, {required bool fireFinalCallback}) {
    final initial = _state;
    if (initial == null || initial.currentPhase == Phase.finished) return false;
    var s = initial;

    final phaseChangedCb = onPhaseChanged;
    onPhaseChanged = null;
    var advanced = false;
    // 防御：0 分钟时长的极端配置下按相位数封顶，避免无限循环。
    final maxSteps = s.rounds.length *
            (s.multiCycle ? (s.totalCycles > 0 ? s.totalCycles : 100) : 1) *
            2 +
        2;
    var steps = 0;
    final savedSaving = _savingPaused;
    _savingPaused = true;
    try {
      while (steps++ < maxSteps && s.currentPhase != Phase.finished) {
        final phaseDuration = _phaseDuration(s);
        final elapsed = now.difference(s.phaseStartTime);
        if (elapsed < phaseDuration) break;
        final transitionTime = s.phaseStartTime.add(phaseDuration);
        _advancePhase(transitionTime);
        advanced = true;
        s = _state!;
        // 新一轮学习必须经用户点击“知道了”确认后才真正开始，
        // 因此补时一旦进入学习阶段就停止推进，等待确认后再继续，
        // 避免后台时长足够时把所有轮次静默推进到“全部完成”。
        if (s.currentPhase == Phase.learning) {
          break;
        }
      }

      if (advanced) {
        _refreshRemaining(now);
        // 休息结束进入下一轮学习：先暂停并等待用户确认（界面弹出“知道了”确认框），
        // 避免下一轮学习在后台/恢复阶段未经确认就自动开始倒计时。
        if (_state!.currentPhase == Phase.learning) {
          // 点击“知道了”那一刻才真正开始这一轮学习：从“休息结束”到用户确认之间
          // 流逝的后台时间不应计入学习，因此剩余时间重置为完整时长，确认后再从零倒计时。
          _remaining = Duration(minutes: _state!.studyMinutes);
          pause();
        }
      }
    } finally {
      onPhaseChanged = phaseChangedCb;
      _savingPaused = savedSaving;
    }

    if (advanced && fireFinalCallback) {
      onPhaseChanged?.call();
    }
    return advanced;
  }

  Duration _phaseDuration(SessionState s) => Duration(
        minutes: s.currentPhase == Phase.learning ? s.studyMinutes : s.breakMinutes,
      );

  void _refreshRemaining(DateTime now) {
    final s = _state;
    if (s == null || s.currentPhase == Phase.finished) {
      _remaining = Duration.zero;
      return;
    }
    final phaseDuration = _phaseDuration(s);
    final elapsed = now.difference(s.phaseStartTime);
    _remaining = elapsed >= phaseDuration ? Duration.zero : phaseDuration - elapsed;
  }

  void _advancePhase(DateTime transitionTime) {
    if (_state == null || _state!.currentPhase == Phase.finished) return;

    if (_state!.currentPhase == Phase.learning) {
      final s = _state!;
      final isLastRound = s.roundIndex >= s.rounds.length - 1;
      final isLastCycle = s.totalCycles > 0 && s.currentCycle >= s.totalCycles;
      final hasNextLearning =
          !isLastRound || (s.multiCycle && !isLastCycle);

      if (hasNextLearning) {
        _state = s.copyWith(
          currentPhase: Phase.breaking,
          phaseStartTime: transitionTime,
        );
        _emitStudyPhaseCompleted(s, transitionTime);
      } else {
        _state = s.copyWith(currentPhase: Phase.finished);
        _tickTimer?.cancel();
        _tickTimer = null;
        _storage.clearSession();
        _emitStudyPhaseCompleted(s, transitionTime);
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
              phaseStartTime: transitionTime,
            );
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
          phaseStartTime: transitionTime,
        );
      }
    }

    _refreshRemaining(DateTime.now());
    onPhaseChanged?.call();
    final s = _state;
    if (s == null || s.currentPhase == Phase.finished) {
      ForegroundService.instance.stop();
    } else if (!_savingPaused) {
      _storage.saveSession(s);
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
    if (!_savingPaused) {
      _storage.saveSession(_state!);
    }
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

    final now = DateTime.now();
    final phaseDuration = _phaseDuration(saved);
    final elapsed = now.difference(saved.phaseStartTime);

    if (elapsed >= phaseDuration) {
      // 后台期间可能有多个阶段连续结束：按墙钟时间连续推进。
      // 恢复时向 UI 暴露最终过渡：若补时后进入学习阶段，调用方（界面）会暂停并
      // 弹出“休息结束”确认框，等待用户点击“知道了”再开始，而非自动倒计时。
      _lastTransitionFromBackground = true;
      _catchUpPhases(now, fireFinalCallback: true);
    } else {
      _remaining = phaseDuration - elapsed;
    }

    // 补时后的最终状态在此落盘：_catchUpPhases 不在循环内保存，
    // 这里等待写入完成，避免返回后仍有在途写入或并发覆盖。
    // 若补时已推进到 finished，_advancePhase 内已触发 clearSession 删除文件，
    // 不再重复写入，避免删除与写入并发争用同一文件（Windows 下 errno 32）。
    if (_state!.currentPhase != Phase.finished) {
      await _storage.saveSession(_state!);
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

  /// 仅用于测试：模拟 App 在后台/锁屏挂起 [elapsedSincePhaseStart] 后回到前台，
  /// 立即触发一次 [_tick] 以执行后台补时推进。
  @visibleForTesting
  void simulateBackgroundCatchUp(Duration elapsedSincePhaseStart) {
    final s = _state;
    if (s == null) return;
    _state =
        s.copyWith(phaseStartTime: DateTime.now().subtract(elapsedSincePhaseStart));
    _tick();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}
