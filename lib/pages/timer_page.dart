import 'package:flutter/material.dart';
import '../models/session_state.dart';
import '../models/study_preset.dart';
import '../models/daily_record.dart';
import '../services/timer_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/timer_display.dart';
import '../widgets/control_buttons.dart';
import '../widgets/preset_card.dart';
import '../widgets/stats_card.dart';
import '../widgets/phase_overlay.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  late final TimerService _timerService;
  late final NotificationService _notificationService;
  late final StorageService _storageService;
  bool _showOverlay = false;
  String _overlayTitle = '';
  String _overlayBody = '';
  bool _overlayModal = false;
  int _totalStudySeconds = 0;
  int _completedCycles = 0;

  final _defaultPreset = const StudyPreset(
    id: 'default',
    name: '默认方案',
    studyMinutes: 2,
    breakMinutes: 1,
    totalCycles: 4,
  );

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _notificationService = NotificationService();
    _timerService = TimerService(_storageService);

    _timerService.onPhaseChanged = _onPhaseChanged;
    _timerService.addListener(_onTimerUpdate);

    _initAsync();
  }

  void _onTimerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initAsync() async {
    await _notificationService.initialize();
    await _timerService.restoreFromStorage();
    await _loadTodayRecord();
    if (mounted) setState(() {});
  }

  Future<void> _loadTodayRecord() async {
    final record = await _storageService.loadTodayRecord();
    if (record != null) {
      _totalStudySeconds = record.totalStudySeconds;
      _completedCycles = record.completedCycles;
    }
  }

  Future<void> _saveTodayRecord() async {
    final record = DailyRecord(
      date: DateTime.now(),
      totalStudySeconds: _totalStudySeconds,
      completedCycles: _completedCycles,
    );
    await _storageService.saveTodayRecord(record);
  }

  void _onPhaseChanged() {
    if (!mounted) return;
    final s = _timerService.state;
    if (s == null) return;
    setState(() {
      if (s.currentPhase == Phase.breaking) {
        _overlayTitle = '学习结束！';
        _overlayBody = '休息 ${s.breakMinutes} 分钟';
        _overlayModal = false;
        _totalStudySeconds += s.studyMinutes * 60;
        if (s.totalCycles == 0 || s.currentCycle <= s.totalCycles) {
          _completedCycles++;
        }
        _saveTodayRecord();
      } else if (s.currentPhase == Phase.learning) {
        _overlayTitle = '休息结束！';
        _overlayBody = '开始第 ${s.currentCycle} 轮学习';
        _overlayModal = true;
        _timerService.pause();
      } else if (s.currentPhase == Phase.finished) {
        _overlayTitle = '全部完成！';
        _overlayBody = '今天的学习任务已完成';
        _overlayModal = false;
        _saveTodayRecord();
      }
      _showOverlay = true;
    });
  }

  Future<void> _handleStart() async {
    await _timerService.start(_defaultPreset);
    if (_timerService.state != null) {
      await _notificationService.schedulePhaseNotifications(_timerService.state!);
    }
    setState(() {});
  }

  void _handlePause() {
    _timerService.pause();
    setState(() {});
  }

  void _handleResume() {
    _timerService.resume();
    setState(() {});
  }

  Future<void> _handleStop() async {
    _notificationService.cancelAll();
    await _timerService.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _timerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _timerService.state;
    final remaining = _timerService.remaining;
    final isRunning = _timerService.isRunning;
    final isPaused = state?.isPaused ?? false;
    final isFinished = _timerService.isFinished;

    final bgColor = state?.currentPhase == Phase.breaking
        ? const Color(0xFFF1F8E9)
        : const Color(0xFFE3F2FD);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('学习计时器'),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  if (remaining != null && state != null)
                    TimerDisplay(
                      remaining: remaining,
                      phase: state.currentPhase,
                      currentCycle: state.currentCycle,
                      totalCycles: state.totalCycles,
                      progress: _timerService.progress,
                    )
                  else
                    TimerDisplay(
                      remaining: Duration.zero,
                      phase: Phase.finished,
                      currentCycle: 0,
                      totalCycles: _defaultPreset.totalCycles,
                      progress: 0,
                    ),
                  const Spacer(flex: 2),
                  ControlButtons(
                    isRunning: isRunning,
                    isPaused: isPaused,
                    isFinished: isFinished,
                    onStart: _handleStart,
                    onPause: _handlePause,
                    onResume: _handleResume,
                    onStop: _handleStop,
                  ),
                  const Spacer(flex: 1),
                  PresetCard(preset: _defaultPreset),
                  const SizedBox(height: 12),
                  StatsCard(
                    totalStudySeconds: _totalStudySeconds,
                    completedCycles: _completedCycles,
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
        if (_showOverlay && state != null)
          PhaseOverlay(
            title: _overlayTitle,
            body: _overlayBody,
            phase: state.currentPhase,
            remaining: state.currentPhase == Phase.breaking ? remaining : null,
            modal: _overlayModal,
            onDismiss: () {
              if (_overlayModal) {
                _timerService.resume();
              }
              setState(() => _showOverlay = false);
            },
          ),
      ],
    );
  }
}
