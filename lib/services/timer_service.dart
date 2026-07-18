import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session_state.dart';
import '../models/study_preset.dart';
import 'storage_service.dart';

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

  VoidCallback? onPhaseChanged;

  Future<void> start(StudyPreset preset) async {
    final now = DateTime.now();
    _state = SessionState(
      startTime: now,
      studyMinutes: preset.studyMinutes,
      breakMinutes: preset.breakMinutes,
      totalCycles: preset.totalCycles,
      currentCycle: 1,
      currentPhase: Phase.learning,
      phaseStartTime: now,
    );
    _remaining = Duration(minutes: preset.studyMinutes);
    await _storage.saveSession(_state!);
    _startTick();
    notifyListeners();
  }

  void _startTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _tick() {
    if (_state == null || _state!.isPaused) return;
    final r = _remaining;
    if (r == null) return;
    _remaining = r - const Duration(seconds: 1);
    if (_remaining!.inSeconds <= 0) {
      _advancePhase();
    }
    notifyListeners();
  }

  void _advancePhase() {
    if (_state == null) return;

    if (_state!.currentPhase == Phase.learning) {
      _state = _state!.copyWith(
        currentPhase: Phase.breaking,
        phaseStartTime: DateTime.now(),
      );
      _remaining = Duration(minutes: _state!.breakMinutes);
    } else if (_state!.currentPhase == Phase.breaking) {
      final nextCycle = _state!.currentCycle + 1;
      if (_state!.totalCycles > 0 && nextCycle > _state!.totalCycles) {
        _state = _state!.copyWith(currentPhase: Phase.finished);
        _tickTimer?.cancel();
        _tickTimer = null;
        _storage.clearSession();
      } else {
        _state = _state!.copyWith(
          currentCycle: nextCycle,
          currentPhase: Phase.learning,
          phaseStartTime: DateTime.now(),
        );
        _remaining = Duration(minutes: _state!.studyMinutes);
      }
    }

    onPhaseChanged?.call();
    _storage.saveSession(_state!);
    notifyListeners();
  }

  void pause() {
    if (_state == null || _state!.isPaused) return;
    _state = _state!.copyWith(isPaused: true, elapsedBeforePause: _remaining);
    _storage.saveSession(_state!);
    notifyListeners();
  }

  void resume() {
    if (_state == null || !_state!.isPaused) return;
    _state = _state!.copyWith(isPaused: false);
    _storage.saveSession(_state!);
    notifyListeners();
  }

  Future<void> stop() async {
    _tickTimer?.cancel();
    _tickTimer = null;
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
      _advancePhase();
    } else {
      _remaining = remaining;
    }

    _startTick();
    notifyListeners();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}
