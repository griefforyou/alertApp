import 'package:flutter/material.dart';
import '../models/session_state.dart';
import '../models/study_preset.dart';
import '../models/daily_record.dart';
import '../models/timer_profile.dart';
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
  Map<String, int> _statsSeconds = {};
  Map<String, int> _statsCycles = {};

  List<TimerProfile> _profiles = [];
  int _selectedIndex = 0;

  TimerProfile get _profile => _selectedIndex < _profiles.length ? _profiles[_selectedIndex] : TimerProfile.defaults().first;
  String get _typeName => _profile.displayName;
  int get _currentSeconds => _statsSeconds[_profile.id] ?? 0;
  int get _currentCycles => _statsCycles[_profile.id] ?? 0;

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
    _profiles = await _storageService.loadProfiles();
    await _timerService.restoreFromStorage();
    await _loadTodayRecord();
    if (mounted) setState(() {});
  }

  int get _displayStudySeconds {
    final base = _currentSeconds;
    final s = _timerService.state;
    final r = _timerService.remaining;
    if (s == null || r == null || s.currentPhase != Phase.learning) {
      return base;
    }
    final elapsed = s.studyMinutes * 60 - r.inSeconds;
    if (elapsed < 0) return base;
    return base + elapsed;
  }

  Future<void> _loadTodayRecord() async {
    final record = await _storageService.loadTodayRecord();
    if (record != null) {
      _statsSeconds = Map.from(record.perTypeStats.map((k, v) => MapEntry(k, v.totalStudySeconds)));
      _statsCycles = Map.from(record.perTypeStats.map((k, v) => MapEntry(k, v.completedCycles)));
    }
  }

  void _addStats(int seconds, int cycles) {
    final id = _profile.id;
    _statsSeconds[id] = (_statsSeconds[id] ?? 0) + seconds;
    _statsCycles[id] = (_statsCycles[id] ?? 0) + cycles;
  }

  Future<void> _saveTodayRecord() async {
    final perType = <String, PerTypeStats>{};
    for (final id in _statsSeconds.keys) {
      perType[id] = PerTypeStats(
        totalStudySeconds: _statsSeconds[id] ?? 0,
        completedCycles: _statsCycles[id] ?? 0,
      );
    }
    final record = DailyRecord(
      date: DateTime.now(),
      perTypeStats: perType,
    );
    await _storageService.saveTodayRecord(record);
  }

  void _onPhaseChanged() {
    if (!mounted) return;
    final s = _timerService.state;
    if (s == null) return;
    setState(() {
      if (s.currentPhase == Phase.breaking) {
        _overlayTitle = '$_typeName结束！';
        _overlayBody = '休息 ${s.breakMinutes} 分钟';
        _overlayModal = false;
        _addStats(s.studyMinutes * 60, 1);
        _saveTodayRecord();
      } else if (s.currentPhase == Phase.learning) {
        _overlayTitle = '休息结束！';
        _overlayBody = '开始第 ${s.currentCycle} 轮$_typeName';
        _overlayModal = true;
        _timerService.pause();
      } else if (s.currentPhase == Phase.finished) {
        _overlayTitle = '全部完成！';
        _overlayBody = '今天的$_typeName任务已完成';
        _overlayModal = false;
        _addStats(s.studyMinutes * 60, 1);
        _saveTodayRecord();
      }
      _showOverlay = true;
    });
  }

  void _switchProfile(int index) {
    if (index == _selectedIndex) return;
    if (_timerService.state != null) {
      _timerService.stop();
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _handleAddProfile() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义类型'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '例如：跑步、阅读、瑜伽',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final v = nameController.text.trim();
              if (v.isEmpty) return;
              Navigator.of(ctx).pop(v);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final profile = TimerProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: TimerCategory.custom,
      customName: name,
      studyMinutes: 2,
      breakMinutes: 1,
      totalCycles: 4,
    );
    setState(() {
      _profiles.add(profile);
      _selectedIndex = _profiles.length - 1;
    });
    await _storageService.saveProfiles(_profiles);
  }

  Future<void> _handleDeleteProfile(int index) async {
    final profile = _profiles[index];
    if (profile.category != TimerCategory.custom) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除类型'),
        content: Text('确定要删除「${profile.displayName}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _profiles.removeAt(index);
      if (_selectedIndex >= _profiles.length) _selectedIndex = _profiles.length - 1;
    });
    await _storageService.saveProfiles(_profiles);
  }

  Future<void> _handleStart() async {
    final preset = StudyPreset(
      id: _profile.id,
      name: _profile.displayName,
      studyMinutes: _profile.studyMinutes,
      breakMinutes: _profile.breakMinutes,
      totalCycles: _profile.totalCycles,
    );
    await _timerService.start(preset);
    if (_timerService.state != null) {
      await _notificationService.schedulePhaseNotifications(
        _timerService.state!,
        typeName: _typeName,
      );
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认结束'),
        content: Text('当前$_typeName进度将丢失，确定要结束吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('结束'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final s = _timerService.state;
    if (s != null) {
      final r = _timerService.remaining;
      int addSec = 0;
      if (s.currentPhase == Phase.learning && r != null) {
        final elapsed = s.studyMinutes * 60 - r.inSeconds;
        if (elapsed > 0) addSec = elapsed;
      } else if (s.currentPhase == Phase.breaking || s.currentPhase == Phase.finished) {
        addSec = s.studyMinutes * 60;
      }
      if (addSec > 0) _addStats(addSec, 0);
      _saveTodayRecord();
    }
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
            title: const Text('计时器'),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _profiles.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == _profiles.length) {
                          return Center(
                            child: ActionChip(
                              avatar: const Icon(Icons.add, size: 18),
                              label: const Text('添加'),
                              onPressed: _timerService.state != null ? null : _handleAddProfile,
                            ),
                          );
                        }
                        final p = _profiles[index];
                        final selected = index == _selectedIndex;
                        final canDelete = p.category == TimerCategory.custom && !selected;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.displayName),
                              if (canDelete) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _handleDeleteProfile(index),
                                  child: const Icon(Icons.close, size: 14),
                                ),
                              ],
                            ],
                          ),
                          selected: selected,
                          onSelected: _timerService.state != null ? null : (_) => _switchProfile(index),
                        );
                      },
                    ),
                  ),
                  const Spacer(flex: 2),
                  if (remaining != null && state != null)
                    TimerDisplay(
                      remaining: remaining,
                      phase: state.currentPhase,
                      currentCycle: state.currentCycle,
                      totalCycles: state.totalCycles,
                      progress: _timerService.progress,
                      typeName: _typeName,
                    )
                  else
                    TimerDisplay(
                      remaining: Duration.zero,
                      phase: Phase.idle,
                      currentCycle: 0,
                      totalCycles: _profile.totalCycles,
                      progress: 0,
                      studyMinutes: _profile.studyMinutes,
                      breakMinutes: _profile.breakMinutes,
                      typeName: _typeName,
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
                  PresetCard(
                    preset: StudyPreset(
                      id: _profile.id,
                      name: _profile.displayName,
                      studyMinutes: _profile.studyMinutes,
                      breakMinutes: _profile.breakMinutes,
                      totalCycles: _profile.totalCycles,
                    ),
                    typeName: _typeName,
                  ),
                  const SizedBox(height: 12),
                  StatsCard(
                    totalStudySeconds: _displayStudySeconds,
                    completedCycles: _currentCycles,
                    typeName: _typeName,
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
