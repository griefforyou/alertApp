# 学习循环计时器 App — 设计文档

日期: 2026-07-19
状态: 设计确认，待实现

---

## 1. 概述

一个跨平台（iOS + Android）的学习循环计时器 App，用户可以设定学习时长→休息时长→循环 N 轮，到点时通过系统通知+声音+前台全屏文字提醒。采用渐进式交付策略：MVP 先出核心计时功能，后续迭代添加预设管理和完整统计。

---

## 2. 技术选型

| 项目 | 选择 | 理由 |
|------|------|------|
| 框架 | Flutter | 一套代码同时发布 iOS 和 Android |
| 状态管理 | ChangeNotifier + ListenableBuilder | 零外部依赖，MVP 够用 |
| 本地存储 | JSON 文件（path_provider） | 简单可靠，后续可平滑迁移到 SQLite |
| 通知 | flutter_local_notifications | 成熟稳定，支持 Android 和 iOS |
| 图表（第三阶段） | fl_chart | 轻量，Flutter 生态首选 |

---

## 3. 架构

```
┌─────────────────────────────────────┐
│              UI Layer                │
│  ┌──────────────┐  ┌──────────────┐  │
│  │ TimerPage    │  │ StatsPage    │  │
│  │ 主页面       │  │ 统计页面     │  │
│  └──────┬───────┘  └──────┬───────┘  │
├─────────┼──────────────────┼──────────┤
│         ▼                  ▼          │
│  ┌──────────────┐  ┌──────────────┐  │
│  │ TimerService │  │ StatsService │  │
│  │ 计时核心     │  │ 统计查询     │  │
│  └──────┬───────┘  └──────┬───────┘  │
├─────────┼──────────────────┼──────────┤
│         ▼                  ▼          │
│  ┌──────────────┐  ┌──────────────┐  │
│  │ Notification │  │   Storage    │  │
│  │ 本地通知管理  │  │  JSON 持久化 │  │
│  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────┘
```

### 3.1 各层职责

**TimerService**
- 管理计时状态（当前阶段、倒计时、循环进度）
- 暴露 ValueNotifier 供 UI 监听
- 计时核心方法：start()、pause()、resume()、reset()

**TimerService** 通过记录会话开始时间 + 持久化 SessionState 实现后台恢复。App 被杀后重新打开时，读取保存的状态并重新计算当前阶段位置。

**Notification**
- 封装 flutter_local_notifications
- 会话开始时一次性调度整个周期的所有通知点
- 提供取消通知（用户手动结束会话时）

**Storage**
- MVP 阶段使用 JSON 文件存储
- 保存 SessionState（当前活跃会话）和 DailyRecord（每日统计）

---

## 4. 数据模型

```dart
enum Phase { learning, breaking, finished }

class SessionState {
  final DateTime startTime;
  final int studyMinutes;
  final int breakMinutes;
  final int totalCycles;     // 0 表示无限循环
  final int currentCycle;
  final Phase currentPhase;
  final DateTime phaseStartTime;
  final bool isPaused;
  final Duration pausedRemaining; // 暂停时已过去的时间
}

class StudyPreset {
  final String id;
  final String name;
  final int studyMinutes;
  final int breakMinutes;
  final int totalCycles;     // 0 表示无限
}

class DailyRecord {
  final DateTime date;
  final int totalStudySeconds;
  final int completedCycles;
  final List<SessionRecord> sessions;
}

class SessionRecord {
  final DateTime startTime;
  final DateTime endTime;
  final int completedCycles;
  final int totalStudySeconds;
}
```

---

## 5. 核心逻辑：计时恢复机制

App 不依赖后台进程持续运行，而是通过「记录 + 计算」实现准确恢复：

1. 会话开始时，完整保存 `SessionState` 到本地 JSON
2. App 被杀或切后台：已调度的系统通知不受影响，到点照常弹出
3. App 重新打开时：读取 `SessionState`，用 `DateTime.now() - session.startTime` 计算当前应该处于哪个阶段，直接跳到正确状态
4. 用 `Timer.periodic(Duration(seconds: 1))` 实时更新前台倒计时显示

### 通知调度策略

会话开始时一次性计算所有通知时间点并调度：
- 每轮的学习结束通知
- 每轮的休息结束通知
- 全部会话完成通知（非无限循环模式）
- 通知带自定义声音，点击后跳转到 App 计时页面

---

## 6. 界面设计

### 6.1 计时器页（唯一页面，第一阶段）

```
┌──────────────────────────────┐
│       学习计时器              │
│                              │
│          25:00               │  大号数字（剩余时间）
│                              │
│      学习中 · 第 1/4 轮      │  当前阶段和进度
│                              │
│  ████████░░░░░░░░░░░░  45%   │  进度条
│                              │
│     [  开始 / 暂停  ]       │  控制按钮
│                              │
│  ┌────────────────────────┐  │
│  │ 📋 预设: 上班前         │  │  预设选择卡片
│  │    学25分 · 休5分 · 4轮 │  │
│  └────────────────────────┘  │
│                              │
│  📊 今日学习: 1h 15m         │  今日统计卡片
│  完成 3 轮                   │
└──────────────────────────────┘
```

- 学习中蓝色调，休息中切换为绿色调
- 时间到→全屏半透明遮罩+大号文字+振动+「知道了」按钮

### 6.2 预设管理页（第二阶段）

弹窗式管理，支持新建/编辑/删除预设。预设持久化到本地 JSON。

### 6.3 统计页（第三阶段）

新增第二 tab，包含今日概览、近 7 天柱状图、月视图日历、历史会话列表。

---

## 7. 分阶段交付计划

### 第一阶段（MVP）

| 功能 | 说明 |
|------|------|
| 计时器 | 1 个内置默认预设（学45休10，4轮） |
| 手动开始/暂停 | 点击按钮控制 |
| 系统通知 + 声音 | 所有阶段转换点触发 |
| 前台全屏提醒 | 时间到→大号文字遮罩 |
| 今日统计卡片 | 底部显示累计学习时长和完成轮数 |
| 后台恢复 | App 被杀后恢复计时状态 |

### 第二阶段

| 功能 | 说明 |
|------|------|
| 预设管理 | 新建/编辑/删除预设方案 |
| 预设选择 | 计时页点击预设卡片切换 |
| 多个预设存储 | 持久化到 JSON |

### 第三阶段

| 功能 | 说明 |
|------|------|
| 统计页面 | 第二 tab，完整统计 |
| 周趋势图表 | fl_chart 柱状图 |
| 月视图日历 | 带学习标记 |
| 历史记录 | 每次会话详情列表 |

---

## 8. 错误处理

| 场景 | 处理方式 |
|------|----------|
| 通知权限被拒绝 | 首次启动时请求权限，拒绝后显示引导提示 |
| 存储文件损坏 | catch 异常，重置为默认状态，不崩溃 |
| 恢复时发现过去时间超出会话总时长 | 标记会话为已完成，显示完成状态 |
| 暂停后恢复 | 从暂停时刻继续倒计时，不丢失已过去时间 |

---

## 9. 测试策略

- **单元测试：** TimerService 核心逻辑（开始/暂停/恢复/循环推进）、SessionState 恢复计算
- **Widget 测试：** 计时器页面主要状态渲染（学习中/休息中/已完成）
- **集成测试：** 通知调度 + App 杀后台恢复流程（通过模拟时间推进）

---

## 10. 边界情况

- 学习时长或休息时长为 0 → 跳过对应阶段
- 总轮数为 0 → 无限循环，直到手动停止
- 手机重启 → 从 JSON 恢复 SessionState，重新计算当前阶段
- 跨天运行 → 以开始时间为基准计算，不受日期变更影响
