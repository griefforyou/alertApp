# 学习循环计时器 MVP 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 构建 MVP 版本的学习循环计时器——一个可运行的跨平台 App，支持学习-休息循环计时、系统通知提醒、前台全屏提醒、后台恢复和今日统计概览。

**架构:** Flutter + ChangeNotifier 状态管理。TimerService 通过持久化 SessionState 实现后台恢复，Notification 使用 flutter_local_notifications 调度所有通知点，Storage 用 JSON 文件存储会话状态和每日统计。

**Tech Stack:** Flutter, dart-lang, flutter_local_notifications, path_provider, shared_preferences

## Global Constraints

- 内置默认预设: 学习45分钟, 休息10分钟, 4轮循环
- 学习阶段蓝色调 (#2196F3)，休息阶段绿色调 (#4CAF50)
- 所有用户可见文案使用中文
- 最低支持 Android 5.0 (API 21) / iOS 13.0
- 零外部状态管理依赖（使用内置 ChangeNotifier）

---

## File Structure

```
alertApp/
├── lib/
│   ├── main.dart                    # App 入口, 主题配置
│   ├── models/
│   │   ├── session_state.dart       # 会话状态模型
│   │   ├── study_preset.dart        # 预设模型
│   │   └── daily_record.dart        # 每日统计模型
│   ├── services/
│   │   ├── timer_service.dart       # 计时核心逻辑
│   │   ├── notification_service.dart # 通知调度管理
│   │   └── storage_service.dart     # JSON 持久化
│   ├── pages/
│   │   └── timer_page.dart          # 计时器主页面
│   └── widgets/
│       ├── timer_display.dart       # 大号倒计时显示
│       ├── control_buttons.dart     # 开始/暂停按钮
│       ├── preset_card.dart         # 预设选择卡片
│       ├── stats_card.dart          # 今日统计卡片
│       └── phase_overlay.dart       # 阶段切换全屏遮罩
├── test/
│   ├── services/
│   │   └── timer_service_test.dart  # TimerService 单元测试
│   ├── services/
│   │   └── storage_service_test.dart # StorageService 单元测试
│   └── widgets/
│       └── timer_display_test.dart  # TimerDisplay widget 测试
└── pubspec.yaml
```

---

### Task 1: 项目脚手架 + 依赖配置

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `analysis_options.yaml`

**Interfaces:**
- Consumes: (无依赖)
- Produces: 可编译运行的 Flutter 项目骨架

- [ ] **Step 1: 创建 Flutter 项目**

```bash
flutter create --org com.studytimer --project-name study_timer .
```

- [ ] **Step 2: 设置 pubspec.yaml 依赖**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_local_notifications: ^18.0.0
  path_provider: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

- [ ] **Step 3: 生成默认 presets JSON 资源文件**

创建 `assets/default_presets.json`:
```json
[
  {
    "id": "default",
    "name": "默认方案",
    "studyMinutes": 45,
    "breakMinutes": 10,
    "totalCycles": 4
  }
]
```

在 pubspec.yaml 中添加:
```yaml
flutter:
  assets:
    - assets/default_presets.json
```

- [ ] **Step 4: 编写最小 main.dart 验证**

```dart
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyTimerApp());
}

class StudyTimerApp extends StatelessWidget {
  const StudyTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学习计时器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2196F3),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const TimerPage(),
    );
  }
}
```

- [ ] **Step 5: 验证项目可编译**

```bash
flutter analyze
```
Expected: no errors (可能有一些未使用的导入警告，忽略)

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: scaffold Flutter project with dependencies"
```

---

### Task 2: 数据模型

**Files:**
- Create: `lib/models/session_state.dart`
- Create: `lib/models/study_preset.dart`
- Create: `lib/models/daily_record.dart`

**Interfaces:**
- Consumes: (无依赖)
- Produces: `SessionState`, `StudyPreset`, `DailyRecord`, `SessionRecord` — 所有后续服务层的输入输出类型

- [ ] **Step 1: 编写 session_state.dart**

```dart
enum Phase { learning, breaking, finished }

class SessionState {
  final DateTime startTime;
  final int studyMinutes;
  final int breakMinutes;
  final int totalCycles; // 0 = 无限
  final int currentCycle;
  final Phase currentPhase;
  final DateTime phaseStartTime;
  final bool isPaused;
  final Duration elapsedBeforePause;

  const SessionState({
    required this.startTime,
    required this.studyMinutes,
    required this.breakMinutes,
    required this.totalCycles,
    required this.currentCycle,
    required this.currentPhase,
    required this.phaseStartTime,
    this.isPaused = false,
    this.elapsedBeforePause = Duration.zero,
  });

  SessionState copyWith({
    DateTime? startTime,
    int? studyMinutes,
    int? breakMinutes,
    int? totalCycles,
    int? currentCycle,
    Phase? currentPhase,
    DateTime? phaseStartTime,
    bool? isPaused,
    Duration? elapsedBeforePause,
  }) {
    return SessionState(
      startTime: startTime ?? this.startTime,
      studyMinutes: studyMinutes ?? this.studyMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      totalCycles: totalCycles ?? this.totalCycles,
      currentCycle: currentCycle ?? this.currentCycle,
      currentPhase: currentPhase ?? this.currentPhase,
      phaseStartTime: phaseStartTime ?? this.phaseStartTime,
      isPaused: isPaused ?? this.isPaused,
      elapsedBeforePause: elapsedBeforePause ?? this.elapsedBeforePause,
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'studyMinutes': studyMinutes,
    'breakMinutes': breakMinutes,
    'totalCycles': totalCycles,
    'currentCycle': currentCycle,
    'currentPhase': currentPhase.name,
    'phaseStartTime': phaseStartTime.toIso8601String(),
    'isPaused': isPaused,
    'elapsedBeforePauseMillis': elapsedBeforePause.inMilliseconds,
  };

  factory SessionState.fromJson(Map<String, dynamic> json) => SessionState(
    startTime: DateTime.parse(json['startTime'] as String),
    studyMinutes: json['studyMinutes'] as int,
    breakMinutes: json['breakMinutes'] as int,
    totalCycles: json['totalCycles'] as int,
    currentCycle: json['currentCycle'] as int,
    currentPhase: Phase.values.byName(json['currentPhase'] as String),
    phaseStartTime: DateTime.parse(json['phaseStartTime'] as String),
    isPaused: json['isPaused'] as bool? ?? false,
    elapsedBeforePause: Duration(milliseconds: json['elapsedBeforePauseMillis'] as int? ?? 0),
  );
}
```

- [ ] **Step 2: 编写 study_preset.dart**

```dart
class StudyPreset {
  final String id;
  final String name;
  final int studyMinutes;
  final int breakMinutes;
  final int totalCycles;

  const StudyPreset({
    required this.id,
    required this.name,
    required this.studyMinutes,
    required this.breakMinutes,
    required this.totalCycles,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'studyMinutes': studyMinutes,
    'breakMinutes': breakMinutes,
    'totalCycles': totalCycles,
  };

  factory StudyPreset.fromJson(Map<String, dynamic> json) => StudyPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    studyMinutes: json['studyMinutes'] as int,
    breakMinutes: json['breakMinutes'] as int,
    totalCycles: json['totalCycles'] as int,
  );
}
```

- [ ] **Step 3: 编写 daily_record.dart**

```dart
class SessionRecord {
  final DateTime startTime;
  final DateTime endTime;
  final int completedCycles;
  final int totalStudySeconds;

  const SessionRecord({
    required this.startTime,
    required this.endTime,
    required this.completedCycles,
    required this.totalStudySeconds,
  });

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'completedCycles': completedCycles,
    'totalStudySeconds': totalStudySeconds,
  };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    completedCycles: json['completedCycles'] as int,
    totalStudySeconds: json['totalStudySeconds'] as int,
  );
}

class DailyRecord {
  final DateTime date;
  final int totalStudySeconds;
  final int completedCycles;
  final List<SessionRecord> sessions;

  const DailyRecord({
    required this.date,
    this.totalStudySeconds = 0,
    this.completedCycles = 0,
    this.sessions = const [],
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'totalStudySeconds': totalStudySeconds,
    'completedCycles': completedCycles,
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
    date: DateTime.parse(json['date'] as String),
    totalStudySeconds: json['totalStudySeconds'] as int,
    completedCycles: json['completedCycles'] as int,
    sessions: (json['sessions'] as List)
        .map((s) => SessionRecord.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}
```

- [ ] **Step 4: 验证编译**

```bash
flutter analyze lib/models/
```
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add lib/models/ && git commit -m "feat: add data models"
```

---

### Task 3: Storage Service（JSON 持久化）

**Files:**
- Create: `lib/services/storage_service.dart`
- Create: `test/services/storage_service_test.dart`

**Interfaces:**
- Consumes: `SessionState`, `DailyRecord` (model classes from Task 2)
- Produces: `Future<SessionState?> loadSession()`、`Future<void> saveSession(SessionState)`、`Future<void> clearSession()`、`Future<DailyRecord> loadTodayRecord()`、`Future<void> saveTodayRecord(DailyRecord)`

- [ ] **Step 1: 编写 storage_service.dart**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session_state.dart';
import '../models/daily_record.dart';

class StorageService {
  static const _sessionFile = 'current_session.json';
  static const _todayRecordFile = 'today_record.json';

  Future<Directory> get _storageDir => getApplicationDocumentsDirectory();

  Future<SessionState?> loadSession() async {
    try {
      final dir = await _storageDir;
      final file = File('${dir.path}/$_sessionFile');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SessionState.fromJson(json);
    } catch (e) {
      debugPrint('Failed to load session: $e');
      return null;
    }
  }

  Future<void> saveSession(SessionState session) async {
    final dir = await _storageDir;
    final file = File('${dir.path}/$_sessionFile');
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    final dir = await _storageDir;
    final file = File('${dir.path}/$_sessionFile');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<DailyRecord?> loadTodayRecord() async {
    try {
      final dir = await _storageDir;
      final file = File('${dir.path}/$_todayRecordFile');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return DailyRecord.fromJson(json);
    } catch (e) {
      debugPrint('Failed to load today record: $e');
      return null;
    }
  }

  Future<void> saveTodayRecord(DailyRecord record) async {
    final dir = await _storageDir;
    final file = File('${dir.path}/$_todayRecordFile');
    await file.writeAsString(jsonEncode(record.toJson()));
  }
}
```

- [ ] **Step 2: 编写 test/services/storage_service_test.dart**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models/session_state.dart';
import 'package:study_timer/services/storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

// Mock path provider
class MockPathProvider extends PathProviderPlatform {
  @override
  Future<Directory> getApplicationDocumentsDirectory() async {
    return Directory.systemTemp.createTemp('test_storage_');
  }
}

void main() {
  late StorageService storage;

  setUp(() {
    PathProviderPlatform.instance = MockPathProvider();
    storage = StorageService();
  });

  test('save and load session', () async {
    final session = SessionState(
      startTime: DateTime(2026, 7, 19, 20, 0),
      studyMinutes: 45,
      breakMinutes: 10,
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
      studyMinutes: 45,
      breakMinutes: 10,
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

  test('save and load today record', () async {
    final record = DailyRecord(
      date: DateTime(2026, 7, 19),
      totalStudySeconds: 2700,
      completedCycles: 1,
      sessions: [
        SessionRecord(
          startTime: DateTime(2026, 7, 19, 20, 0),
          endTime: DateTime(2026, 7, 19, 20, 45),
          completedCycles: 1,
          totalStudySeconds: 2700,
        ),
      ],
    );

    await storage.saveTodayRecord(record);
    final loaded = await storage.loadTodayRecord();

    expect(loaded, isNotNull);
    expect(loaded!.totalStudySeconds, 2700);
    expect(loaded.completedCycles, 1);
  });
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/services/storage_service_test.dart
```
Expected: 4/4 passed

- [ ] **Step 4: Commit**

```bash
git add lib/services/storage_service.dart test/services/storage_service_test.dart
git commit -m "feat: add JSON storage service"
```

---

### Task 4: TimerService（计时核心逻辑）

**Files:**
- Create: `lib/services/timer_service.dart`
- Create: `test/services/timer_service_test.dart`

**Interfaces:**
- Consumes: `SessionState`, `StorageService` (Task 3)
- Produces: `TimerService extends ChangeNotifier` — 暴露 `state`, `remaining`, `progress`, `start()`, `pause()`, `resume()`, `stop()`, `restoreFromStorage()`，供 UI 层绑定

- [ ] **Step 1: 编写 timer_service.dart**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session_state.dart';
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
    if (_state == null) return 0.0;
    final total = Duration(
      minutes: _state!.currentPhase == Phase.learning
          ? _state!.studyMinutes
          : _state!.breakMinutes,
    );
    if (total.inSeconds == 0) return 0.0;
    return 1.0 - (_remaining!.inSeconds / total.inSeconds);
  }

  bool get isRunning => _tickTimer != null;

  bool get isFinished => _state?.currentPhase == Phase.finished;

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
    _remaining = _remaining! - const Duration(seconds: 1);
    if (_remaining!.inSeconds <= 0) {
      _advancePhase();
    }
    notifyListeners();
  }

  void _advancePhase() {
    if (_state == null) return;

    if (_state!.currentPhase == Phase.learning) {
      // Learning finished -> break
      _state = _state!.copyWith(
        currentPhase: Phase.breaking,
        phaseStartTime: DateTime.now(),
      );
      _remaining = Duration(minutes: _state!.breakMinutes);
    } else if (_state!.currentPhase == Phase.breaking) {
      // Break finished -> next cycle or finish
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

    notifyListeners();
  }

  void pause() {
    if (_state == null || _state!.isPaused) return;
    _state = _state!.copyWith(isPaused: true);
    notifyListeners();
  }

  void resume() {
    if (_state == null || !_state!.isPaused) return;
    _state = _state!.copyWith(isPaused: false);
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

    // Calculate current remaining time from elapsed
    final elapsed = DateTime.now().difference(saved.phaseStartTime);
    final phaseDuration = Duration(
      minutes: saved.currentPhase == Phase.learning
          ? saved.studyMinutes
          : saved.breakMinutes,
    );
    final remaining = phaseDuration - elapsed;

    if (remaining.inSeconds <= 0) {
      // Phase already ended while we were away — advance
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
```

- [ ] **Step 2: 编写 timer_service_test.dart**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models/session_state.dart';
import 'package:study_timer/models/study_preset.dart';
import 'package:study_timer/services/timer_service.dart';
import 'package:study_timer/services/storage_service.dart';
import 'dart:io';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class MockPathProvider extends PathProviderPlatform {
  @override
  Future<Directory> getApplicationDocumentsDirectory() async {
    return Directory.systemTemp.createTemp('test_timer_');
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

  group('start', () {
    test('creates session in learning phase', () {
      final preset = StudyPreset(
        id: 'test',
        name: 'Test',
        studyMinutes: 45,
        breakMinutes: 10,
        totalCycles: 4,
      );

      timerService.start(preset);

      expect(timerService.state, isNotNull);
      expect(timerService.state!.currentPhase, Phase.learning);
      expect(timerService.state!.currentCycle, 1);
      expect(timerService.remaining!.inMinutes, 45);
    });

    test('isRunning returns true after start', () {
      final preset = StudyPreset(
        id: 'test', name: 'Test',
        studyMinutes: 25, breakMinutes: 5, totalCycles: 4,
      );

      timerService.start(preset);
      expect(timerService.isRunning, true);
    });
  });

  group('pause and resume', () {
    test('pause sets isPaused', () {
      final preset = StudyPreset(
        id: 'test', name: 'Test',
        studyMinutes: 25, breakMinutes: 5, totalCycles: 4,
      );

      timerService.start(preset);
      timerService.pause();

      expect(timerService.state!.isPaused, true);
      expect(timerService.isRunning, true); // Timer still ticks but does nothing
    });

    test('resume clears isPaused', () {
      final preset = StudyPreset(
        id: 'test', name: 'Test',
        studyMinutes: 25, breakMinutes: 5, totalCycles: 4,
      );

      timerService.start(preset);
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

      timerService.start(preset);
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
```

- [ ] **Step 3: 运行测试**

```bash
flutter test test/services/timer_service_test.dart
```
Expected: all tests passed

- [ ] **Step 4: Commit**

```bash
git add lib/services/timer_service.dart test/services/timer_service_test.dart
git commit -m "feat: add TimerService core logic"
```

---

### Task 5: Notification Service（通知调度）

**Files:**
- Create: `lib/services/notification_service.dart`

**Interfaces:**
- Consumes: `SessionState` (Task 2)
- Produces: `Future<void> initialize()`、`Future<void> schedulePhaseNotifications(SessionState)`、`Future<void> cancelAll()`

- [ ] **Step 1: 编写 notification_service.dart**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/session_state.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> schedulePhaseNotifications(SessionState session) async {
    await cancelAll();

    int totalSeconds = 0;
    int cycle = session.currentCycle;
    Phase phase = session.currentPhase;

    while (true) {
      if (cycle > session.totalCycles && session.totalCycles > 0) break;
      if (session.totalCycles == 0 && cycle > 100) break; // safety limit for infinite

      if (phase == Phase.learning) {
        totalSeconds += session.studyMinutes * 60;
        await _scheduleNotification(
          id: cycle * 2 - 1,
          title: '学习结束',
          body: '第 $cycle 轮学习完成！休息 ${session.breakMinutes} 分钟',
          secondsFromNow: totalSeconds,
        );
        phase = Phase.breaking;
      } else {
        totalSeconds += session.breakMinutes * 60;
        await _scheduleNotification(
          id: cycle * 2,
          title: '休息结束',
          body: '休息时间到！开始第 ${cycle + 1} 轮学习',
          secondsFromNow: totalSeconds,
        );
        phase = Phase.learning;
        cycle++;
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int secondsFromNow,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'study_timer_channel',
      '学习计时器',
      channelDescription: '学习计时器提醒通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.schedule(
      id,
      title,
      body,
      DateTime.now().add(Duration(seconds: secondsFromNow)),
      details,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
flutter analyze lib/services/notification_service.dart
```
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat: add notification scheduling service"
```

---

### Task 6: Timer Page UI（计时器主页面）

**Files:**
- Create: `lib/widgets/timer_display.dart`
- Create: `lib/widgets/control_buttons.dart`
- Create: `lib/pages/timer_page.dart`
- Create: `test/widgets/timer_display_test.dart`

**Interfaces:**
- Consumes: `TimerService` (Task 4)、`NotificationService` (Task 5)、`StorageService` (Task 3)
- Produces: `TimerPage` — 完整的主界面，包含倒计时显示、控制按钮、预设卡片、统计卡片

- [ ] **Step 1: 编写 timer_display.dart**

```dart
import 'package:flutter/material.dart';
import '../models/session_state.dart';

class TimerDisplay extends StatelessWidget {
  final Duration remaining;
  final Phase phase;
  final int currentCycle;
  final int totalCycles;
  final double progress;

  const TimerDisplay({
    super.key,
    required this.remaining,
    required this.phase,
    required this.currentCycle,
    required this.totalCycles,
    required this.progress,
  });

  String get _timeText {
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (remaining.inHours > 0) {
      final h = remaining.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  String get _phaseText {
    switch (phase) {
      case Phase.learning:
        return '学习中';
      case Phase.breaking:
        return '休息中';
      case Phase.finished:
        return '已完成';
    }
  }

  String get _cycleText {
    if (phase == Phase.finished) return '所有轮次已完成';
    if (totalCycles == 0) return '第 $currentCycle 轮（无限循环）';
    return '第 $currentCycle/$totalCycles 轮';
  }

  @override
  Widget build(BuildContext context) {
    final color = phase == Phase.learning
        ? const Color(0xFF2196F3)
        : phase == Phase.breaking
            ? const Color(0xFF4CAF50)
            : const Color(0xFF9E9E9E);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _phaseText,
          style: TextStyle(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _timeText,
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w200,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _cycleText,
          style: TextStyle(
            fontSize: 16,
            color: color.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 编写 control_buttons.dart**

```dart
import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;
  final bool isFinished;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const ControlButtons({
    super.key,
    required this.isRunning,
    required this.isPaused,
    required this.isFinished,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (isFinished) {
      return ElevatedButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.refresh),
        label: const Text('重新开始'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      );
    }

    if (!isRunning) {
      return ElevatedButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(fontSize: 18),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          label: const Text('结束'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: isPaused ? onResume : onPause,
          icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
          label: Text(isPaused ? '继续' : '暂停'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: 编写 timer_page.dart**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/session_state.dart';
import '../models/study_preset.dart';
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
  StreamSubscription? _overlaySub;

  final _defaultPreset = const StudyPreset(
    id: 'default',
    name: '默认方案',
    studyMinutes: 45,
    breakMinutes: 10,
    totalCycles: 4,
  );

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _notificationService = NotificationService();
    _timerService = TimerService(_storageService);

    _initAsync();
  }

  Future<void> _initAsync() async {
    await _notificationService.initialize();
    await _timerService.restoreFromStorage();

    if (_timerService.state != null) {
      _scheduleOverlayCheck();
    }

    if (mounted) setState(() {});
  }

  void _scheduleOverlayCheck() {
    _overlaySub?.cancel();
    _overlaySub = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (!mounted) return;
      // The overlay is triggered by the phase advance callback
    });
  }

  Future<void> _handleStart() async {
    await _timerService.start(_defaultPreset);
    if (_timerService.state != null) {
      await _notificationService.schedulePhaseNotifications(_timerService.state!);
    }
    _scheduleOverlayCheck();
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
    await _notificationService.cancelAll();
    _overlaySub?.cancel();
    await _timerService.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _overlaySub?.cancel();
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

    return Scaffold(
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
              const StatsCard(),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 编写 timer_display_test.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/widgets/timer_display.dart';
import 'package:study_timer/models/session_state.dart';

void main() {
  group('TimerDisplay', () {
    testWidgets('shows learning phase in blue', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TimerDisplay(
            remaining: const Duration(minutes: 45),
            phase: Phase.learning,
            currentCycle: 1,
            totalCycles: 4,
            progress: 0.0,
          ),
        ),
      ));

      expect(find.text('学习中'), findsOneWidget);
      expect(find.text('45:00'), findsOneWidget);
      expect(find.text('第 1/4 轮'), findsOneWidget);
    });

    testWidgets('shows breaking phase in green', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TimerDisplay(
            remaining: const Duration(minutes: 10),
            phase: Phase.breaking,
            currentCycle: 1,
            totalCycles: 4,
            progress: 0.5,
          ),
        ),
      ));

      expect(find.text('休息中'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('shows finished state', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TimerDisplay(
            remaining: Duration.zero,
            phase: Phase.finished,
            currentCycle: 4,
            totalCycles: 4,
            progress: 1.0,
          ),
        ),
      ));

      expect(find.text('已完成'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 5: 验证编译+运行 widget 测试**

```bash
flutter analyze lib/pages/timer_page.dart
flutter test test/widgets/timer_display_test.dart
```
Expected: no errors, tests pass

- [ ] **Step 6: Commit**

```bash
git add lib/pages/timer_page.dart lib/widgets/timer_display.dart lib/widgets/control_buttons.dart
git add test/widgets/timer_display_test.dart
git commit -m "feat: add timer page with display and controls"
```

---

### Task 7: 预设卡片 + 统计卡片 Widget

**Files:**
- Create: `lib/widgets/preset_card.dart`
- Create: `lib/widgets/stats_card.dart`
- Create: `test/widgets/preset_card_test.dart` (optional)
- Create: `test/widgets/stats_card_test.dart` (optional)

**Interfaces:**
- Consumes: `StudyPreset` (Task 2)
- Produces: `PresetCard`、`StatsCard`

- [ ] **Step 1: 编写 preset_card.dart**

```dart
import 'package:flutter/material.dart';
import '../models/study_preset.dart';

class PresetCard extends StatelessWidget {
  final StudyPreset preset;
  final VoidCallback? onTap;

  const PresetCard({
    super.key,
    required this.preset,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFF2196F3)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '学${preset.studyMinutes}分 · 休${preset.breakMinutes}分 · ${preset.totalCycles > 0 ? '${preset.totalCycles}轮' : '无限循环'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 编写 stats_card.dart**

```dart
import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  const StatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    // MVP: hardcoded placeholder, to be connected to storage in Phase 3
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.bar_chart, color: Color(0xFF2196F3)),
            const SizedBox(width: 12),
            const Text(
              '今日学习: ',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '0h 0m',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2196F3),
              ),
            ),
            const Spacer(),
            Text(
              '完成 0 轮',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 验证编译**

```bash
flutter analyze lib/widgets/
```
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/preset_card.dart lib/widgets/stats_card.dart
git commit -m "feat: add preset card and stats card widgets"
```

---

### Task 8: 阶段切换全屏遮罩

**Files:**
- Create: `lib/widgets/phase_overlay.dart`

**Interfaces:**
- Consumes: (无外部依赖，纯 UI 组件)
- Produces: `PhaseOverlay` — 全屏半透明遮罩 + 大号文字 +「知道了」按钮

- [ ] **Step 1: 编写 phase_overlay.dart**

```dart
import 'package:flutter/material.dart';
import '../models/session_state.dart';

class PhaseOverlay extends StatelessWidget {
  final String title;
  final String body;
  final Phase phase;
  final VoidCallback onDismiss;

  const PhaseOverlay({
    super.key,
    required this.title,
    required this.body,
    required this.phase,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = phase == Phase.learning
        ? const Color(0xFF2196F3)
        : const Color(0xFF4CAF50);

    return Material(
      color: color.withOpacity(0.95),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                phase == Phase.learning ? Icons.menu_book : Icons.free_breakfast,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('知道了'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 在 timer_page.dart 中集成遮罩逻辑**

在 `_TimerPageState` 中添加遮罩触发方法，监听 `TimerService` 的阶段变化:

```dart
// 在 _TimerPageState 中添加:
void _onPhaseChanged(Phase newPhase) {
  if (!mounted) return;
  setState(() {
    if (newPhase == Phase.breaking) {
      _overlayTitle = '学习结束！';
      _overlayBody = '休息 ${_timerService.state!.breakMinutes} 分钟';
    } else if (newPhase == Phase.learning) {
      _overlayTitle = '休息结束！';
      _overlayBody = '开始第 ${_timerService.state!.currentCycle} 轮学习';
    } else if (newPhase == Phase.finished) {
      _overlayTitle = '全部完成！';
      _overlayBody = '今天的学习任务已完成';
    }
    _showOverlay = true;
  });
}
```

- [ ] **Step 3: 在 timer_page.dart 的 build 方法中添加 overlay**

在 Scaffold 返回前包裹 Stack:

```dart
return Stack(
  children: [
    Scaffold(/* ... existing body ... */),
    if (_showOverlay)
      PhaseOverlay(
        title: _overlayTitle,
        body: _overlayBody,
        phase: state?.currentPhase ?? Phase.learning,
        onDismiss: () {
          setState(() => _showOverlay = false);
        },
      ),
  ],
);
```

- [ ] **Step 4: 验证编译**

```bash
flutter analyze lib/widgets/phase_overlay.dart
```
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/phase_overlay.dart
git commit -m "feat: add fullscreen phase transition overlay"
```

---

### Task 9: 接入 main.dart + 最终集成

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/pages/timer_page.dart`

**Interfaces:**
- Consumes: All previous tasks
- Produces: 可运行的 App

- [ ] **Step 1: 更新 main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/timer_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const StudyTimerApp());
}

class StudyTimerApp extends StatelessWidget {
  const StudyTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学习计时器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2196F3),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const TimerPage(),
    );
  }
}
```

- [ ] **Step 2: 补全 timer_page.dart 中的遮罩触发**

将 `_tick` 中的阶段变化与 overlay 逻辑连接。在 `TimerService` 中添加回调:

```dart
// 在 timer_service.dart 中:
class TimerService extends ChangeNotifier {
  // ... existing fields ...
  VoidCallback? onPhaseChanged;

  void _advancePhase() {
    // ... existing logic ...
    onPhaseChanged?.call();
    notifyListeners();
  }
}
```

在 `_TimerPageState.initState` 中:

```dart
_timerService.onPhaseChanged = () {
  if (!mounted) return;
  final s = _timerService.state;
  if (s == null) return;
  setState(() {
    if (s.currentPhase == Phase.breaking) {
      _overlayTitle = '学习结束！';
      _overlayBody = '休息 ${s.breakMinutes} 分钟';
    } else if (s.currentPhase == Phase.learning) {
      _overlayTitle = '休息结束！';
      _overlayBody = '开始第 ${s.currentCycle} 轮学习';
    } else if (s.currentPhase == Phase.finished) {
      _overlayTitle = '全部完成！';
      _overlayBody = '今天的学习任务已完成';
    }
    _showOverlay = true;
  });
};
```

- [ ] **Step 3: 验证完全编译**

```bash
flutter analyze
flutter test
```
Expected: no errors, all tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/pages/timer_page.dart lib/services/timer_service.dart
git commit -m "feat: integrate all components, add phase change callback"
```

---

### Task 10: TimerService 进阶测试（恢复 + 边界情况）

**Files:**
- Modify: `test/services/timer_service_test.dart`

- [ ] **Step 1: 添加恢复测试**

```dart
group('restoreFromStorage', () {
  test('restores saved session', () async {
    final state = SessionState(
      startTime: DateTime.now().subtract(const Duration(minutes: 10)),
      studyMinutes: 45,
      breakMinutes: 10,
      totalCycles: 4,
      currentCycle: 1,
      currentPhase: Phase.learning,
      phaseStartTime: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    await storageService.saveSession(state);

    final service = TimerService(storageService);
    await service.restoreFromStorage();

    expect(service.state, isNotNull);
    expect(service.state!.studyMinutes, 45);
    expect(service.remaining!.inMinutes, 35); // 45 - 10 elapsed
  });

  test('restores finished session', () async {
    final state = SessionState(
      startTime: DateTime.now().subtract(const Duration(hours: 2)),
      studyMinutes: 45,
      breakMinutes: 10,
      totalCycles: 4,
      currentCycle: 4,
      currentPhase: Phase.finished,
      phaseStartTime: DateTime.now(),
    );
    await storageService.saveSession(state);

    final service = TimerService(storageService);
    await service.restoreFromStorage();

    expect(service.isFinished, true);
    expect(service.remaining!.inSeconds, 0);
  });
});
```

- [ ] **Step 2: 运行全部测试**

```bash
flutter test
```
Expected: all tests pass

- [ ] **Step 3: Commit**

```bash
git add test/services/timer_service_test.dart
git commit -m "test: add timer service restore and edge case tests"
```

---

## Self-Review

**Spec coverage:** 
- ✅ 计时器核心逻辑 — Task 4 (TimerService)
- ✅ 手动开始/暂停 — Task 4 (start/pause/resume)
- ✅ 系统通知 + 声音 — Task 5 (NotificationService)
- ✅ 前台全屏提醒 — Task 8 (PhaseOverlay)
- ✅ 后台恢复 — Task 4 (restoreFromStorage)
- ✅ 今日统计卡片 — Task 7 (StatsCard, MVP 占位)
- ✅ 内置默认预设 — Task 6 (_defaultPreset)

**Placeholder check:** 无 TBD/TODO。StatsCard 的今日数据在 MVP 阶段显示为默认值，后续阶段接入真实数据。

**Type consistency:** 所有类型签名在任务间一致。SessionState 的 toJson/fromJson 在 Task 2、Task 3、Task 4 中保持相同字段名。

**Scope check:** MVP 范围清晰——只做核心计时 + 通知 + 恢复 + 今日概览。预设管理和完整统计留到后续阶段。
