import "package:flutter/material.dart";
import "package:flutter/gestures.dart";
import "../models/session_state.dart";
import "../models/daily_record.dart";
import "../models/timer_profile.dart";
import "../services/timer_service.dart";
import "../services/notification_service.dart";
import "../services/sound_service.dart";
import "../services/sound_picker_service.dart";
import "../services/storage_service.dart";
import "../widgets/timer_display.dart";
import "../widgets/control_buttons.dart";
import "../widgets/preset_card.dart";
import "../widgets/stats_card.dart";
import "../widgets/phase_overlay.dart";
import "preset_edit_page.dart";

class TimerPage extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ThemeMode themeMode;
  const TimerPage({super.key, this.onThemeModeChanged, this.themeMode = ThemeMode.system});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  late final TimerService _timerService;
  late final NotificationService _notificationService;
  late final SoundService _soundService;
  late final StorageService _storageService;
  late final SoundPickerService _soundPickerService;
  String _notificationSoundUri = 'default';
  String _notificationSoundTitle = '默认系统铃声';
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayBody = "";
  bool _overlayModal = false;
  Map<String, int> _statsSeconds = {};
  Map<String, int> _statsCycles = {};

  List<TimerProfile> _profiles = [];
  int _selectedIndex = 0;
  bool _editMode = false;
  final _chipScrollController = ScrollController();

  TimerProfile get _profile => _selectedIndex < _profiles.length ? _profiles[_selectedIndex] : TimerProfile.defaults().first;
  String get _typeName => _profile.displayName;
  int get _currentSeconds => _statsSeconds[_profile.id] ?? 0;
  int get _currentCycles => _statsCycles[_profile.id] ?? 0;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _notificationService = NotificationService();
    _soundService = SoundService();
    _soundPickerService = SoundPickerService();
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
    final savedUri = await _storageService.loadNotificationSoundUri();
    _notificationSoundUri = savedUri;
    _notificationService.setSoundUri(savedUri != 'default' ? savedUri : null);
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

  String _groupText(SessionState s) {
    if (s.rounds.length <= 1) return '';
    return '第 ${s.roundIndex + 1} 组 · ';
  }

  void _onPhaseChanged() {
    if (!mounted) return;
    final s = _timerService.state;
    if (s == null) return;
    setState(() {
      if (s.currentPhase == Phase.breaking) {
        _overlayTitle = "$_typeName结束！";
        _overlayBody = "${_groupText(s)}休息 ${s.breakMinutes} 分钟";
        _overlayModal = false;
        _addStats(s.studyMinutes * 60, 1);
        _saveTodayRecord();
        _notificationService.showNotification(
          title: "$_typeName结束",
          body: _overlayBody,
        );
        _soundService.playBeep();
      } else if (s.currentPhase == Phase.learning) {
        _overlayTitle = "休息结束！";
        _overlayBody = "${_groupText(s)}开始第 ${s.currentCycle} 轮$_typeName";
        _overlayModal = true;
        _timerService.pause();
        _notificationService.showNotification(
          title: "休息结束",
          body: _overlayBody,
        );
        _soundService.playBeep();
      } else if (s.currentPhase == Phase.finished) {
        _overlayTitle = "全部完成！";
        _overlayBody = "今天的$_typeName任务已完成";
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

  Set<String> get _existingNames =>
      {for (final p in _profiles) p.displayName};

  Future<void> _handleAddProfile() async {
    final nameController = TextEditingController();
    String? errorText;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("自定义类型"),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: "名称",
              hintText: "例如：跑步、阅读、瑜伽",
              errorText: errorText,
            ),
            onChanged: (_) {
              setDialogState(() => errorText = null);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("取消"),
            ),
            FilledButton(
              onPressed: () {
                final v = nameController.text.trim();
                if (v.isEmpty) return;
                if (_existingNames.contains(v)) {
                  setDialogState(() => errorText = "该名称已存在");
                  return;
                }
                Navigator.of(ctx).pop(v);
              },
              child: const Text("添加"),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    final profile = TimerProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: TimerCategory.custom,
      customName: name,
      multiCycle: true,
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
        title: const Text("删除类型"),
        content: Text("确定要删除「${profile.displayName}」吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text("删除"),
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

  Future<void> _handleRenameProfile(int index) async {
    final profile = _profiles[index];
    if (profile.category != TimerCategory.custom) return;
    final controller = TextEditingController(text: profile.customName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("修改名称"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "名称",
            hintText: "例如：跑步、阅读、瑜伽",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isEmpty) return;
              Navigator.of(ctx).pop(v);
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() {
      _profiles[index] = profile.copyWith(customName: name);
    });
    await _storageService.saveProfiles(_profiles);
  }

  Future<void> _handleStart() async {
    await _timerService.start(_profile);
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
        title: const Text("确认结束"),
        content: Text("当前$_typeName进度将丢失，确定要结束吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text("结束"),
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

  void _showThemeSettings() {
    final currentMode = widget.themeMode;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text("设置",
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              _ThemeTile(
                icon: Icons.light_mode,
                label: "浅色",
                selected: currentMode == ThemeMode.light,
                onTap: () {
                  widget.onThemeModeChanged?.call(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              _ThemeTile(
                icon: Icons.dark_mode,
                label: "深色",
                selected: currentMode == ThemeMode.dark,
                onTap: () {
                  widget.onThemeModeChanged?.call(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              _ThemeTile(
                icon: Icons.settings_brightness,
                label: "跟随系统",
                selected: currentMode == ThemeMode.system,
                onTap: () {
                  widget.onThemeModeChanged?.call(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              _ThemeTile(
                icon: Icons.notifications_outlined,
                label: "通知铃声",
                subtitle: _notificationSoundTitle,
                selected: false,
                onTap: () {
                  Navigator.pop(ctx);
                  _showNotificationSoundPicker();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNotificationSoundPicker() async {
    final sounds = await _soundPickerService.getNotificationSounds();
    if (!mounted) return;
    final selectedUri = _notificationSoundUri;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text("选择通知铃声",
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              if (sounds.isEmpty && selectedUri == 'default')
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text("当前仅支持默认系统铃声\n可在系统通知设置中更换", textAlign: TextAlign.center)),
                ),
              SizedBox(
                height: (sounds.length + 1) * 56.0 > 360 ? 360 : (sounds.length + 1) * 56.0,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.volume_up_outlined),
                      title: const Text("默认系统铃声"),
                      trailing: selectedUri == 'default' ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
                      onTap: () {
                        _notificationSoundUri = 'default';
                        _notificationSoundTitle = '默认系统铃声';
                        _notificationService.setSoundUri(null);
                        _storageService.saveNotificationSoundUri('default');
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                    ),
                    ...sounds.map((s) {
                      final uri = s['uri'] ?? '';
                      final title = s['title'] ?? 'Unknown';
                      return ListTile(
                        leading: const Icon(Icons.music_note_outlined),
                        title: Text(title),
                        trailing: selectedUri == uri ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
                        onTap: () {
                          _notificationSoundUri = uri;
                          _notificationSoundTitle = title;
                          _notificationService.setSoundUri(uri);
                          _storageService.saveNotificationSoundUri(uri);
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleEditProfile() async {
    final result = await Navigator.push<TimerProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => PresetEditPage(profile: _profile),
      ),
    );
    if (result == null || !mounted) return;
    final idx = _profiles.indexWhere((p) => p.id == result.id);
    if (idx < 0) return;
    setState(() {
      _profiles[idx] = result;
    });
    await _storageService.saveProfiles(_profiles);
  }

  Widget _buildProfileChip(int index) {
    final p = _profiles[index];
    final selected = index == _selectedIndex;
    final isCustom = p.category == TimerCategory.custom;
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: ChoiceChip(
            label: Text(p.displayName, overflow: TextOverflow.ellipsis),
            selected: selected,
            onSelected: _editMode
                ? (isCustom ? (_) => _handleRenameProfile(index) : null)
                : (_timerService.state != null ? null : (_) => _switchProfile(index)),
          ),
          ),
          if (_editMode && isCustom)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () => _handleDeleteProfile(index),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 14, color: Theme.of(context).colorScheme.onError),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timerService.dispose();
    _soundService.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _timerService.state;
    final remaining = _timerService.remaining;
    final isRunning = _timerService.isRunning;
    final isPaused = state?.isPaused ?? false;
    final isFinished = _timerService.isFinished;
    final cs = Theme.of(context).colorScheme;
    final barColor = state?.currentPhase == Phase.breaking ? cs.tertiary : cs.primary;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("计时器"),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: _showThemeSettings,
                tooltip: "主题",
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  height: 3,
                  color: barColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              Expanded(
                                child: Listener(
                                  onPointerSignal: (event) {
                                    if (event is PointerScrollEvent) {
                                      _chipScrollController.jumpTo(
                                        (_chipScrollController.offset + event.scrollDelta.dy).clamp(
                                          _chipScrollController.position.minScrollExtent,
                                          _chipScrollController.position.maxScrollExtent,
                                        ),
                                      );
                                    }
                                  },
                                  child: GestureDetector(
                                    onHorizontalDragUpdate: (details) {
                                      _chipScrollController.jumpTo(
                                        (_chipScrollController.offset - details.delta.dx).clamp(
                                          0.0,
                                          _chipScrollController.position.maxScrollExtent,
                                        ),
                                      );
                                    },
                                    behavior: HitTestBehavior.translucent,
                                    child: SingleChildScrollView(
                                      controller: _chipScrollController,
                                      physics: const NeverScrollableScrollPhysics(),
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          for (int i = 0; i < _profiles.length; i++) ...[
                                            if (i > 0) const SizedBox(width: 8),
                                            _buildProfileChip(i),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_profile.category == TimerCategory.custom)
                                IconButton(
                                  icon: Icon(_editMode ? Icons.check : Icons.edit, size: 20),
                                  onPressed: _timerService.state != null ? null : () => setState(() => _editMode = !_editMode),
                                  tooltip: _editMode ? "完成" : "编辑",
                                ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: _timerService.state != null ? null : _handleAddProfile,
                                tooltip: "添加",
                              ),
                            ],
                          ),
                        ),
                        const Spacer(flex: 2),
                        if (remaining != null && state != null)
                          TimerDisplay(
                            remaining: remaining,
                            phase: state.currentPhase,
                            currentRound: state.roundIndex + 1,
                            totalRounds: state.rounds.length,
                            currentCycle: state.currentCycle,
                            totalCycles: state.totalCycles,
                            progress: _timerService.progress,
                            typeName: _typeName,
                          )
                        else
                          TimerDisplay(
                            remaining: Duration.zero,
                            phase: Phase.idle,
                            currentRound: 1,
                            totalRounds: _profile.rounds.length,
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
                        const SizedBox(height: 24),
                        PresetCard(
                          preset: _profile,
                          typeName: _typeName,
                          onTap: _timerService.state != null ? null : _handleEditProfile,
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
              ],
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

class _ThemeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall) : null,
      trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
      onTap: onTap,
    );
  }
}
