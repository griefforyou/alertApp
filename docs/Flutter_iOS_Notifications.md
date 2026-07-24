# Flutter iOS 本地通知无法发送完整排查文档（flutter_local_notifications）
> 适配 flutter_local_notifications，包含完整依赖、iOS原生配置、工具类、测试页面，直接复制使用

## 一、依赖配置
### 1. pubspec.yaml
```yaml
dependencies:
  flutter_local_notifications: ^17.1.2
  permission_handler: ^11.0.1
  timezone: ^0.9.2 # zonedSchedule 定时通知必须
```

### 2. 执行安装命令
```bash
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
```

## 二、iOS 原生配置（必改三项）
### 1. ios/Runner/Info.plist
右键 Info.plist → Open As → Source Code，在最外层 `<dict>` 内添加：
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>用于日程、定时提醒推送通知</string>
```

### 2. ios/Runner/AppDelegate.swift 完整代码
```swift
import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // 绑定通知代理
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APP 前台运行时展示通知横幅、声音、角标
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.alert, .sound, .badge])
  }
}
```

### 3. Xcode 工程配置
1. Xcode 打开 `ios/Runner.xcworkspace`
2. 选中 Runner Target → Signing & Capabilities
3. `+ Capability` 添加 **Background Modes**
4. Background Modes 勾选：**Remote notifications**
> 本地通知不需要 Push Notifications 推送证书

## 三、Dart 通知工具类 `notification_util.dart`
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin localNotifyPlugin = FlutterLocalNotificationsPlugin();

/// 初始化通知框架
Future<void> initLocalNotification() async {
  // 时区初始化（定时通知必备）
  tz.initializeTimeZones();

  const iosSetting = IOSInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  final initSettings = InitializationSettings(iOS: iosSetting);
  await localNotifyPlugin.initialize(initSettings);
}

/// 请求系统通知权限
Future<bool> requestNotificationPermission() async {
  final PermissionStatus status = await Permission.notification.request();
  if (!status.isGranted) {
    // 跳转系统设置
    await openAppSettings();
  }
  return status.isGranted;
}

/// 立刻弹出即时通知
Future<void> showInstantNotification({
  required int notifyId,
  required String title,
  required String body,
}) async {
  const iosDetail = IOSNotificationDetails();
  final notifyDetail = NotificationDetails(iOS: iosDetail);
  await localNotifyPlugin.show(notifyId, title, body, notifyDetail);
}

/// 延时定时通知
Future<void> scheduleDelayNotification({
  required int notifyId,
  required String title,
  required String body,
  required Duration delay,
}) async {
  const iosDetail = IOSNotificationDetails();
  final notifyDetail = NotificationDetails(iOS: iosDetail);

  await localNotifyPlugin.zonedSchedule(
    notifyId,
    title,
    body,
    tz.TZDateTime.now(tz.local).add(delay),
    notifyDetail,
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

/// 取消指定通知
Future<void> cancelNotification(int notifyId) async {
  await localNotifyPlugin.cancel(notifyId);
}

/// 取消所有本地通知
Future<void> cancelAllNotification() async {
  await localNotifyPlugin.cancelAll();
}
```

## 四、main.dart 挂载初始化
```dart
import 'package:flutter/material.dart';
import 'notification_util.dart';
import 'notification_test_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLocalNotification();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '本地通知测试',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const NotificationTestPage(),
    );
  }
}
```

## 五、通知测试页面 `notification_test_page.dart`
```dart
import 'package:flutter/material.dart';
import 'notification_util.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  String logText = "";

  void addLog(String msg) {
    setState(() {
      logText = "[${DateTime.now().toString()}] $msg\n$logText";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("iOS本地通知测试面板")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () async {
                bool ok = await requestNotificationPermission();
                addLog(ok ? "权限已授予" : "权限被拒绝");
              },
              child: const Text("1. 请求通知权限"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await showInstantNotification(
                  notifyId: 1001,
                  title: "即时通知",
                  body: "测试前台/后台立刻弹窗",
                );
                addLog("已发送即时通知 id:1001");
              },
              child: const Text("2. 测试【即时通知】"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await scheduleDelayNotification(
                  notifyId: 1002,
                  title: "定时提醒",
                  body: "10秒后触发，可以上滑关闭App测试",
                  delay: const Duration(seconds: 10),
                );
                addLog("已注册定时通知 id:1002，10秒后触发");
              },
              child: const Text("3. 测试【10秒定时通知】"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await cancelAllNotification();
                addLog("已清除所有本地通知任务");
              },
              child: const Text("4. 清除全部通知"),
            ),
            const SizedBox(height: 16),
            const Text("运行日志："),
            Expanded(
              child: SingleChildScrollView(
                child: Text(logText, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 六、标准测试步骤（必须真机，模拟器通知不稳定）
1. 卸载手机旧App
2. `flutter clean` 重新编译安装真机
3. 打开页面，点击【1.请求通知权限】并允许
4. 点击【2.即时通知】
   - 前台正常弹窗 = 基础代码没问题
   - 前台无弹窗 → AppDelegate 代理代码缺失
5. 点击【3.10秒定时通知】，**上滑彻底关闭App**，等待观察通知

## 七、高频踩坑汇总
| 现象 | 根因 | 解决方案 |
|------|------|----------|
| 前台看不到横幅，后台正常 | 未实现 `UNUserNotificationCenterDelegate` | 使用文档完整 AppDelegate.swift |
| 前台正常，杀掉App通知消失 | 未开启 Background Modes - Remote notifications | Xcode开启对应配置 |
| 不会弹出权限申请框 | Info.plist 缺少通知用途描述 | 添加 `NSUserNotificationsUsageDescription` |
| 定时任务失效 | 未初始化时区 / 使用旧 schedule API | 使用 `zonedSchedule` + 初始化 timezone |
| 通知偶尔丢失延迟 | 低电量/专注/勿扰模式 | 测试时关闭省电、专注模式 |
| 大量定时通知失效 | iOS上限64条本地定时任务 | 及时清理无用通知 |
| 通知冲突 | FCM + flutter_local_notifications 混用 | 两个SDK通知代理互斥，不要同时启用 |

## 八、自检清单
- [ ] 依赖正常安装，pod install 无报错
- [ ] Info.plist 添加通知权限文案
- [ ] AppDelegate 实现通知代理回调
- [ ] Xcode 开启 Background Modes
- [ ] 使用真机测试，不依赖模拟器
- [ ] 代码主动申请通知权限
- [ ] 定时通知初始化时区库

你可以直接全选复制保存为 `flutter_ios_local_notice.md` 使用。
如果你后续遇到**点击通知跳转页面**需求，我可以继续补充通知点击回调代码。