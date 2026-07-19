# 学习计时器 — 设计方案

## 架构概览

```
lib/
├── main.dart                          # 入口，竖屏锁定，Material 3
├── models/
│   ├── models.dart                    # 桶导出
│   ├── round_config.dart              # 单组 (work+break)
│   ├── timer_profile.dart             # 计时方案 (含多组/多轮循环)
│   ├── session_state.dart             # 进行中的会话快照
│   ├── study_preset.dart              # 旧版扁平方案 (生产未使用)
│   ├── daily_record.dart              # 按日聚合统计
│   └── study_record.dart              # 单次记录 (未持久化)
├── services/
│   ├── timer_service.dart             # 计时引擎 (ChangeNotifier)
│   ├── storage_service.dart           # JSON 文件持久化
│   └── notification_service.dart      # 本地通知调度
├── pages/
│   ├── timer_page.dart                # 主页面
│   └── preset_edit_page.dart          # 方案编辑页
└── widgets/
    ├── timer_display.dart             # 倒计时显示
    ├── control_buttons.dart           # 开始/暂停/继续/结束
    ├── preset_card.dart               # 方案概要卡片
    ├── stats_card.dart                # 今日统计卡片
    └── phase_overlay.dart             # 阶段切换遮罩层
```

## 数据模型

### `TimerCategory` 枚举
- `study` → 显示名 "学习"
- `training` → 显示名 "训练"
- `custom` → 显示名 `customName` 或 "自定义"

### `RoundConfig`
| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `workMinutes` | `int` | 2 | 学习/训练时长（分） |
| `breakMinutes` | `int` | 1 | 休息时长（分） |

方法：`toJson()`、`fromJson()`、`copyWith()`

### `TimerProfile`
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 唯一标识 (内置 `builtin_study`/`builtin_training`；自定义用时间戳) |
| `category` | `TimerCategory` | 类型 |
| `customName` | `String?` | 自定义类型名称 |
| `rounds` | `List<RoundConfig>` | 第 1 组、第 2 组…… |
| `multiCycle` | `bool` | 是否启用多轮循环 |
| `totalCycles` | `int` | 循环轮数 (0=无限) |

**后向兼容**：`fromJson` 检测无 `rounds` 键时从旧 `studyMinutes`/`breakMinutes` 退化为单组。
**Getter 后向兼容**：`studyMinutes` → `rounds[0].workMinutes`，`breakMinutes` → `rounds[0].breakMinutes`。

**两个内置方案**：
- 学习：`[2min工作, 1min休息]`，循环 4 轮
- 训练：`[1min工作, 1min休息]`，循环 8 轮

### `Phase` 枚举
`idle` → `learning` → `breaking` → `finished`

### `SessionState`
| 字段 | 类型 | 说明 |
|------|------|------|
| `startTime` | `DateTime` | 会话开始时间 |
| `rounds` | `List<RoundConfig>` | 组序列快照 |
| `roundIndex` | `int` | 当前在第几组 (0-based) |
| `multiCycle` | `bool` | 是否多轮循环 |
| `totalCycles` | `int` | 总循环数 (0=无限) |
| `currentCycle` | `int` | 当前第几轮 (1-based) |
| `currentPhase` | `Phase` | 当前阶段 |
| `phaseStartTime` | `DateTime` | 当前阶段开始时间 |
| `isPaused` | `bool` | 暂停标记 |
| `elapsedBeforePause` | `Duration` | 已耗用时间 |

**Getter 后向兼容**：`studyMinutes` → `rounds[roundIndex].workMinutes`，`breakMinutes` → `rounds[roundIndex].breakMinutes`

## 计时引擎 (TimerService)

基于 `ChangeNotifier`，1 秒 `Timer.periodic` 驱动。

### 状态机：`_advancePhase()`

```
learning ──→ breaking ──→ learning (下一组 或 下一轮) ──→ ... ──→ finished
```

**learning → breaking**：
1. 若还有后续学习阶段（不是最后一组，或多循环且还有下轮）→ 进入 `Phase.breaking`，剩余时间取当前组休息时长
2. 否则 → 进入 `Phase.finished`

**breaking → learning**：
1. `roundIndex + 1`：
   - 若超出组数且 `multiCycle == true` → `roundIndex = 0`，`currentCycle + 1`；若循环数耗尽 → `finished`
   - 若超出组数且 `multiCycle == false` → `finished`
   - 若未超出 → 进入下一组 `Phase.learning`

### 公开 API

| 方法 | 行为 |
|------|------|
| `start(TimerProfile)` | 创建 `SessionState(rounds, roundIndex=0, cycle=1, learning)`，启动 tick，存 storage |
| `pause()` | 设 `isPaused=true`，保存当前剩余时间 |
| `resume()` | 清 `isPaused`，启动 tick |
| `stop()` | 取消 timer，清 `state`/`remaining`，删 storage |
| `restoreFromStorage()` | 从 JSON 恢复会话；若阶段已过期则静默推进（抑制 `onPhaseChanged`） |

### 属性

`state`、`remaining`、`progress`（0.0–1.0）、`isRunning`、`isFinished`、`onPhaseChanged`（回调）

### 恢复逻辑

1. 无已存会话 → 静默返回
2. 暂停中 → `remaining = elapsedBeforePause`，不长 tick
3. 已完成 → `remaining = 0`，不长 tick
4. 进行中 → 计算 wall-time elapsed，若剩余 ≤ 0 则静默推进阶段，否则恢复倒计时

## 持久化 (StorageService)

写入 `getApplicationDocumentsDirectory()`，抛出或文件缺失时返回 null/默认值。

| 文件 | 内容 |
|------|------|
| `current_session.json` | `SessionState` |
| `today_record.json` | `DailyRecord` |
| `timer_profiles.json` | `List<TimerProfile>` (无文件时 fallback 为内置方案) |

方法：`loadSession`/`saveSession`/`clearSession`、`loadTodayRecord`/`saveTodayRecord`/`clearTodayRecord`、`loadProfiles`/`saveProfiles`

## 本地通知 (NotificationService)

使用 `flutter_local_notifications` + `timezone`，`zonedSchedule`（精确+省电模式）。

### 通知调度：`schedulePhaseNotifications(session, {typeName})`

从当前阶段开始遍历所有未来的 learning/break 阶段（最多 100 轮），计算绝对时间偏移：

| 阶段 | 标题 | 正文 |
|------|------|------|
| learning → breaking | `${typeName}结束` | `第 ${cycle} 轮${typeName}完成！休息 ${breakMinutes} 分钟` |
| breaking → learning | `休息结束` | `休息时间到！开始第 ${cycle+1} 轮${typeName}` |

注意：
- 通知仍使用「轮」术语
- 调度前调用 `cancelAll()` 去重
- 异常静默 `debugPrint`

## 页面

### 主页面 (TimerPage)

布局（垂直 Column）：
1. **顶部 profile 选择器**：`ListView` + `ChoiceChip`，内置不可删，自定义额外显示关闭图标（仅非选中时），所有 chip 在会话激活时禁用。末尾有添加 chip。
2. **倒计时显示** (`TimerDisplay`)
3. **控制按钮** (`ControlButtons`)
4. **方案卡片** (`PresetCard`) — 闲置时可点击跳转编辑
5. **今日统计** (`StatsCard`)
6. **阶段切换遮罩** (`PhaseOverlay`)

**阶段切换弹窗 (`_onPhaseChanged`)**：

| 转换 | 标题 | 正文 | 模态 | 额外行为 |
|------|------|------|------|----------|
| learning → breaking | `学习结束！` | `休息 X 分钟` | 否 | 累加统计并写入今日记录 |
| breaking → learning | `休息结束！` | `开始第 X 轮学习` | 是 | 自动暂停，用户手动点"知道了"后继续 |
| → finished | `全部完成！` | `今天的学习任务已完成` | 否 | 累加统计并写入今日记录 |

**今日统计**：实时累加已完成的秒数/轮数，精确到当前进行中的 learning 阶段 (`_displayStudySeconds`)。

**自定义类型添加流程**：`AlertDialog` 输入名称 → 创建 `TimerProfile(category: custom)` → 追加列表并选中 → 保存 profiles。

**编辑流程**：`Navigator.push(PresetEditPage)` → 回传修改后的 `TimerProfile` → 替换 `_profiles` 并保存。

**停止流程**：确认对话框 → 若当前是 learning 阶段则记录部分时长 → 取消通知 → `timerService.stop()`。

### 方案编辑页 (PresetEditPage)

**布局**：
1. 自定义名称 `TextField`（仅 `TimerCategory.custom`）
2. 组列表 `_RoundCard`：
   - 头部：**第 N 组**
   - 学习/训练时长 `_DurationRow`（± stepper，最小 1）
   - 休息时长 `_DurationRow`
   - 删除按钮「删除本组」（仅多于 1 组时显示）
3. **添加下一组** `OutlinedButton`
4. **多轮循环** `CheckboxListTile`
5. 循环轮数 `TextField`（仅多轮循环启用时，1–999）
6. 保存 → `Navigator.pop(profile)`

显示名根据类型自动匹配：学习→"学习"、训练→"训练"、自定义→`customName`。

## 组件

### TimerDisplay
- 闲置 → "准备开始"（灰色），`00:00`，**第 1/4 轮**
- 学习中 → "学习中"（蓝色），倒计时，`MM:SS`/`HH:MM:SS`，进度条
- 休息中 → "休息中"（绿色），倒计时，进度条
- 已完成 → "已完成"（灰色），`00:00`

### ControlButtons
- `isFinished` → "重新开始"
- `isPaused` → "结束" + "继续"
- 运行中 → "结束" + "暂停"
- 闲置 → "开始"

### PresetCard
- 单组描述：`学习2分钟，休息1分钟，循环4轮` / `学习2分钟，休息1分钟`（不循环时）
- 多组描述（不循环）：`第1组:学习2分→休息1分 | 第2组:学习3分→休息2分`
- 多组描述（循环）：`第1组:学习2分→休息1分 | 第2组:学习3分→休息2分，循环4轮`

### StatsCard
`今日学习: 0h 0m` + `完成 0 轮`

### PhaseOverlay
全屏遮罩，`PopScope` 阻止返回（模态时），图标（📖/☕），大号标题，正文，可选剩余倒计时，「知道了」按钮。颜色与阶段匹配（蓝/绿）。

## 数据流

```
┌─────────────┐     start(TimerProfile)     ┌──────────────┐
│  TimerPage   │ ──────────────────────────► │ TimerService │
│  (Stateful)  │ ◄── notifyListeners() ───── │ (ChangeNot.) │
└──────┬──────┘                              └──────┬───────┘
       │                                            │
       │ loadProfiles()                     saveSession()
       ▼                                            ▼
┌─────────────┐                            ┌──────────────┐
│ StorageSvc  │                            │ current_     │
│             │◄──── saveProfiles() ──────  │ session.json │
└─────────────┘                            └──────────────┘
       ▲
       │ loadTodayRecord()
       │
   today_record.json
```

挂起时 `SessionState` 序列化到 `current_session.json`；最大离线恢复间隔 1 秒（tick 精度）。

## 测试

25 测试用例，分 4 套：

| 套件 | 文件 | 数量 |
|------|------|------|
| 应用冒烟 | `test/widget_test.dart` | 3 |
| TimerDisplay 渲染 | `test/widgets/timer_display_test.dart` | 3 |
| TimerService 状态机 | `test/services/timer_service_test.dart` | 16 |
| StorageService IO | `test/services/storage_service_test.dart` | 6 |

TimerService 测试覆盖：start/pause/resume/stop/progress/restore（无会话/活动中/已完成/暂停中/过期阶段推进）、isFinished。
