**Flutter 开发倒计时闹钟/提醒类 App** 时，核心原则和原生一样：**不要依赖 Flutter 的 `Timer` 或 `Stream` 在后台/锁屏后继续跑**，因为一旦 App 进入后台或锁屏，Dart 代码基本会被挂起。

必须把「到点提醒」交给**系统级调度**（本地通知 / 精确闹钟）。

### 1. Flutter 生命周期监听（了解当前状态）

用 `WidgetsBindingObserver` 或 `AppLifecycleListener` 监听状态变化：

```dart
class _CountdownPageState extends State<CountdownPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:   // 亮屏前台
        // 恢复 UI 显示
        break;
      case AppLifecycleState.inactive:  // 即将锁屏 / 来电等
        break;
      case AppLifecycleState.paused:    // 后台 / 锁屏
        // 保存当前剩余时间
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

**注意**：这个监听只能帮你**保存状态**和**恢复 UI**，不能保证倒计时继续走。

### 2. 推荐技术方案（2025-2026 可靠方案）

| 平台 | 推荐核心方案 | 说明 |
|------|--------------|------|
| **通用（两端）** | `flutter_local_notifications` + `timezone` | 调度本地通知，App 被杀也能响 |
| **Android 精确闹钟** | `android_alarm_manager_plus` 或 直接用 `flutter_local_notifications` 的 exact alarm | 需要处理 `SCHEDULE_EXACT_ALARM` 权限 |
| **Android 实时显示进度** | 前台 Service（可用 `flutter_foreground_task` 或自定义） | 锁屏后通知栏持续显示剩余时间 |
| **iOS 实时锁屏显示** | Live Activities（需原生代码或插件） | 动态岛 / 锁屏实时倒计时 |
| **两端简单可靠闹钟** | [`alarm`](https://pub.dev/packages/alarm) 插件 | 专门做闹钟，内部用音频保活 + 通知 |

### 3. 最推荐的实践流程（Flutter）

1. **用户点击开始倒计时**  
   - 计算目标时间（现在 + 倒计时秒数）  
   - 立刻用 `flutter_local_notifications` 调度一条**精确本地通知**（到点响铃 + 震动 + 标题）  
   - （可选）同时启动前台任务显示进度

2. **App 进入后台 / 锁屏**  
   - Flutter 代码被挂起 → 没关系  
   - 系统会在设定时间触发通知

3. **用户重新打开 App**  
   - 从本地存储读取目标时间，重新计算剩余时间显示  
   - 如果已经过了目标时间，直接显示「已结束」

4. **取消倒计时**  
   - 取消对应的通知 ID

### 4. 关键权限（Android 必须处理）

Android 12+ / 13+ / 14+ 对精确闹钟限制越来越严：

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/> <!-- 部分场景 -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/> <!-- 如果用前台服务 -->
```

运行时还要请求：
- 通知权限
- 精确闹钟权限（`Permission.scheduleExactAlarm` 或跳转到系统设置）

### 5. 插件推荐组合（当前较稳）

- **基础通知**：`flutter_local_notifications` + `timezone`
- **Android 精确闹钟增强**：`android_alarm_manager_plus`
- **前台保活（显示实时进度）**：`flutter_foreground_task`
- **专门闹钟插件**：`alarm`（适合简单闹钟场景，内部做了不少平台适配）
- **状态持久化**：`shared_preferences` 或 `hive` / `isar`（记录目标结束时间）

### 6. 实际场景对应状态（Flutter）

| 场景 | Flutter 代码状态 | 倒计时/提醒是否可靠 |
|------|------------------|---------------------|
| 亮屏前台 | 正常运行 | 正常（可用 Timer 更新 UI） |
| 亮屏后台 | paused | Timer 停，靠通知保证到点 |
| 自动/手动锁屏 | paused | 同上 |
| 锁屏很久 / App 被杀 | 进程可能已死 | **只要通知调度成功，仍然会响** |

---

**总结建议（Flutter 倒计时闹钟）：**

- **UI 层**：用 Timer 只负责前台漂亮的倒计时动画。
- **业务层**：把「到点」完全交给系统本地通知 / 精确闹钟。
- **不要幻想** Flutter 的 Timer 在锁屏后还能跑。
