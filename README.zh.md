# 学习计时器

基于 Flutter 的多轮次学习计时器，支持自定义计时方案、会话持久化和本地通知。

## 功能特性

- **计时方案** — 内置学习/训练预设，支持自定义多组（学习+休息）配置
- **多轮循环** — 多组方案可循环执行指定轮数（支持无限循环）
- **会话持久化** — 自动保存和恢复会话状态，支持挂起后的墙钟时间恢复
- **本地通知** — 阶段切换通知，基于 `flutter_local_notifications` + `timezone`
- **每日统计** — 累计学习时长和完成的轮数
- **自定义方案** — 添加、编辑和删除用户自定义计时方案

## 项目结构

```
lib/
├── main.dart                       # 入口，竖屏锁定，Material 3
├── models/
│   ├── round_config.dart           # 单组（学习+休息）时长对
│   ├── timer_profile.dart          # 计时方案（含多组/多轮循环）
│   ├── session_state.dart          # 进行中的会话快照
│   ├── daily_record.dart           # 按日聚合统计
│   └── study_record.dart           # 单次记录（未持久化）
├── services/
│   ├── timer_service.dart          # 计时引擎（ChangeNotifier，1 秒周期）
│   ├── storage_service.dart        # JSON 文件持久化
│   └── notification_service.dart   # 本地通知调度
├── pages/
│   ├── timer_page.dart             # 主页面
│   └── preset_edit_page.dart       # 方案编辑页
└── widgets/
    ├── timer_display.dart          # 倒计时显示（含进度条）
    ├── control_buttons.dart        # 开始/暂停/继续/结束
    ├── preset_card.dart            # 方案概要卡片
    ├── stats_card.dart             # 今日统计卡片
    └── phase_overlay.dart          # 阶段切换遮罩层
```

## 数据流

```
TimerPage ──start(TimerProfile)──► TimerService (ChangeNotifier)
    ▲                                  │
    │◄─── notifyListeners() ───────────┘
    │                                  │
    │ loadProfiles()          saveSession()
    ▼                                  ▼
StorageService                   current_session.json
    ▲
    │ loadTodayRecord()
    ▼
today_record.json
```

## 测试

共 25 个测试用例，分 4 套：

| 测试套件 | 文件 | 数量 |
|---------|------|------|
| 应用冒烟 | `test/widget_test.dart` | 3 |
| TimerDisplay 渲染 | `test/widgets/timer_display_test.dart` | 3 |
| TimerService 状态机 | `test/services/timer_service_test.dart` | 16 |
| StorageService IO | `test/services/storage_service_test.dart` | 6 |

## Web 非根目录部署打包
flutter build web --base-href /timer/

flutter build web --release --base-href /timer/