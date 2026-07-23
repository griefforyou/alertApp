# 历史记录功能实现计划

## 需求
- 每完成一个**学习阶段**(learning->breaking 或 learning->finished)产生一条历史记录
- 每条记录含：类型(displayName)、开始时间、时长(秒)
- 独立历史页展示，按日期分组，永久保留
- 不影响现有当天聚合统计(StatsCard)和 daily_record.json

## 数据模型

新增 `lib/models/history_record.dart`:

```dart
class HistoryRecord {
  final String id;          // 唯一标识，用于删除/去重
  final String typeName;    // 类型名：学习/训练/自定义名
  final DateTime startTime; // 学习阶段开始时刻
  final int durationSeconds;// 学习阶段实际时长
  ...
  toJson / fromJson
}
```

存储 key: `HistoryRecord.startTime.toIso8601String()` 保证唯一。

## 存储

`storage_service.dart` 新增两个文件常量与方法:
- `_historyFile = 'history_records.json'`
- `Future<List<HistoryRecord>> loadHistory()` — 读全部记录(单文件 JSON 数组)
- `Future<void> appendHistory(HistoryRecord r)` — 追加一条
- `Future<void> clearHistory()` — 清空(可选)

追加策略:读全量 -> append -> 写全量。记录数可控(永久但一天最多几十条,一年也就万级,单文件无压力)。

## 计时服务回调改造

`timer_service.dart`:
- 现有 `onPhaseChanged` 是无参 `VoidCallback?`。
- **不改签名**,改为在 `_advancePhase` 内部,learning->breaking/finished 转换前,记录「刚结束 learning 阶段」信息到 `timer_service` 的一个新字段 `_completedStudyPhase`(含 startTime=旧phaseStartTime, endTime=now, durationSeconds=studyMinutes*60, typeName 暂不在此设)。
- 问题:`timer_service` 不持有 profile/typeName。typeName 由 `timer_page` 提供。

**最终方案(最小侵入)**:给 `TimerService` 加一个新回调:
```dart
void Function(StudyPhaseCompleted)? onStudyPhaseCompleted;
```
其中 `StudyPhaseCompleted` 是 timer_service.dart 内的小 record:
```dart
class StudyPhaseCompleted {
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
}
```
在 `_advancePhase` 的两个 learning 出口(breaking 转换、finished 转换)调用:
```dart
onStudyPhaseCompleted?.call(StudyPhaseCompleted(
  startTime: s.phaseStartTime,
  endTime: now,
  durationSeconds: s.studyMinutes * 60,
));
```
注意:用 `s.phaseStartTime`(转换前的 learning 开始时间,此时 s 还是旧 state)。

`timer_page._onPhaseChanged` 注册并实现该回调:收到后用当前 `_typeName` + 数据 appendHistory。这样 typeName 由 UI 层提供,符合现有分层(timer_service 不依赖 profile)。

## timer_page 接线

`_initAsync` 或 `initState` 里:
```dart
_timerService.onStudyPhaseCompleted = _onStudyPhaseCompleted;
```

```dart
void _onStudyPhaseCompleted(StudyPhaseCompleted p) {
  final r = HistoryRecord(
    id: p.startTime.toIso8601String(),
    typeName: _typeName,
    startTime: p.startTime,
    durationSeconds: p.durationSeconds,
  );
  _storageService.appendHistory(r);
}
```
注意:避免与现有 `_addStats` 重复写——_addStats 写聚合(daily_record),appendHistory 写明细,两者并行不冲突。`_onPhaseChanged` 里现有的 `_addStats(s.studyMinutes * 60, 1)` 保留。

## 历史页 UI

新增 `lib/pages/history_page.dart`:
- `StatefulWidget`,initState 调 `loadHistory()`
- AppBar 标题"历史记录"，右上可选清空按钮(带确认对话框)
- 用 `ListView`,按日期分组(同一 day 的记录归一组,显示日期 section header + 当日合计)
- 每条记录:左图标(类型色)、类型名、开始时间(HH:mm)、时长(如"25分"/"1时5分")
- 分组按日期倒序(最新在上),组内按时间倒序

## 首页入口

`timer_page.dart` AppBar actions 加一个 IconButton(Icons.history / Icons.assessment),`Navigator.push` 到 `HistoryPage`:
```dart
IconButton(
  icon: const Icon(Icons.history),
  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
  tooltip: "历史记录",
),
```

## 改动文件清单
1. 新增 `lib/models/history_record.dart` — 模型
2. 新增 `lib/pages/history_page.dart` — UI
3. 改 `lib/services/storage_service.dart` — 读写历史
4. 改 `lib/services/timer_service.dart` — 新增 onStudyPhaseCompleted 回调 + 调用点
5. 改 `lib/pages/timer_page.dart` — 注册回调、写明细、AppBar 入口

## 不改动
- daily_record.dart / daily_record.json — 当天聚合照旧
- session_state.dart — 不加字段
- 通知/声音逻辑 — 不碰

## 风险/注意
- `_advancePhase` 有多个 learning 出口(breaking 转换 line ~91, finished line ~97)。都要触发回调,否则漏记。finished 出口在 isLastRound 且无下一学习时。
- restoreFromStorage 路径里若 `remaining<=0` 会调 `_advancePhase`(line 213),也会触发回调——这是后台恢复时补齐,属合理(该阶段确实结束了)。但 onPhaseChanged 被临时置空(line 212-214),onStudyPhaseCompleted 不置空,会触发。需确认此时 _typeName 是否就绪(已 _initAsync 加载 profiles)。为安全,在 timer_page 回调里判 mounted && _profiles 非空。
- 时长用 `studyMinutes*60`,与现有 _addStats 一致(按设定时长,非实际墙钟)。暂停后再继续,墙钟会更长但记录的时长仍是设定值——与现有统计口径一致,保持。
