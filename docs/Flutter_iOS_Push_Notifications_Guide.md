# Flutter iOS 系统通知完整指南

## 📋 目录
1. [环境准备](#环境准备)
2. [Firebase 配置](#firebase-配置)
3. [Xcode 项目配置](#xcode-项目配置)
4. [依赖包安装](#依赖包安装)
5. [代码实现](#代码实现)
6. [测试验证](#测试验证)

---

## 环境准备

- Flutter SDK 最新版本
- Xcode 13+
- Apple 开发者账号
- iOS 设备或模拟器

---

## Firebase 配置

### 步骤 1：创建 Firebase 项目

1. 访问 [Firebase Console](https://console.firebase.google.com/)
2. 点击「新建项目」
3. 输入项目名称，完成创建

### 步骤 2：添加 iOS 应用

1. 在项目首页点击「添加应用」> 选择 iOS
2. 输入你的 iOS Bundle ID（通常格式：`com.example.appname`）
3. 下载 `GoogleService-Info.plist` 文件
4. 将文件拖入 Xcode 的 `ios/Runner` 目录

### 步骤 3：配置 APNs 证书

1. 在 Firebase 控制台 > 项目设置 > Cloud Messaging 标签页
2. 上传 APNs 认证密钥或证书（从 Apple Developer 账户申请）

---

## Xcode 项目配置

### 步骤 1：打开工作区

```bash
cd your_flutter_project
open ios/Runner.xcworkspace
```

### 步骤 2：添加 Capabilities

1. 选择 **Runner** 目标
2. 进入 **Signing & Capabilities** 标签页
3. 点击 **+ Capability**，添加：
   - **Push Notifications**
   - **Background Modes**（勾选 `Remote notifications`）

### 步骤 3：更新 Info.plist

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

---

## 依赖包安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^latest
  firebase_messaging: ^latest
  flutter_local_notifications: ^latest
```

执行：
```bash
flutter pub get
```

---

## 代码实现

### 文件 1：main.dart - 应用入口

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 后台消息处理器（必须是顶级函数）
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 后台通知: ${message.notification?.title}');
  print('📝 内容: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Firebase
  await Firebase.initializeApp();
  
  // 注册后台消息处理器
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 通知演示',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}
```

### 文件 2：notification_service.dart - 通知服务

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// 初始化通知服务
  Future<void> initNotifications() async {
    // 初始化本地通知
    const darwinInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      iOS: darwinInitializationSettings,
    );

    await _localNotificationsPlugin.initialize(initializationSettings);

    // 请求通知权限
    await _requestNotificationPermission();

    // 获取 FCM Token
    await _getFCMToken();

    // 监听前台消息
    _listenForegroundMessages();

    // 监听应用打开的消息
    _listenMessageOpenedApp();
  }

  /// 请求通知权限
  Future<void> _requestNotificationPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('✅ 通知权限: ${settings.authorizationStatus}');
  }

  /// 获取 FCM Token
  Future<void> _getFCMToken() async {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    print('🔐 FCM Token: $token');
    
    // 保存到本地存储或上传到服务器
    // await saveTokenToServer(token);
  }

  /// 监听前台消息（应用运行时）
  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 收到前台消息');
      print('标题: ${message.notification?.title}');
      print('内容: ${message.notification?.body}');

      // 显示本地通知
      _showLocalNotification(message);
    });
  }

  /// 监听应用被通知打开（应用未运行或后台）
  void _listenMessageOpenedApp() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('👆 用户点击了通知');
      print('标题: ${message.notification?.title}');
      
      // 处理跳转逻辑
      _handleNotificationTap(message);
    });
  }

  /// 显示本地通知
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      ),
    );

    await _localNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// 处理通知点击
  void _handleNotificationTap(RemoteMessage message) {
    // 根据消息内容进行页面跳转
    final data = message.data;
    print('通知数据: $data');
    
    // 示例：
    // if (data['type'] == 'news') {
    //   navigateToNewsDetail(data['id']);
    // }
  }

  /// 手动发送本地通知（用于测试）
  Future<void> sendTestNotification() async {
    const notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotificationsPlugin.show(
      0,
      '测试通知标题',
      '这是一条测试通知',
      notificationDetails,
    );
  }
}
```

### 文件 3：home_page.dart - ���页面

```dart
import 'package:flutter/material.dart';
import 'notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.initNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter iOS 通知演示'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              '通知服务已初始化',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _notificationService.sendTestNotification,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              child: const Text(
                '发送测试通知',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 测试验证

### 方法 1：使用 Firebase 控制台

1. 打开 [Firebase Console](https://console.firebase.google.com/)
2. 进入 **Engage** > **Cloud Messaging**
3. 点击「新建广播消息」
4. 填写标题和内容
5. 目标：选择「应用程序 iOS」
6. 点击「发送」

### 方法 2：代码中测试

点击「发送测试通知」按钮，即可看到本地通知效果

### 验证清单

- ✅ 应用前台：是否显示本地通知
- ✅ 应用后台：是否在通知中心显示
- ✅ 点击通知：是否能唤起应用
- ✅ 检查 Console 日志中的 FCM Token

---

## 常见问题

### Q1：通知不显示？
- 检查是否获得了用户权限
- 验证 APNs 证书是否上传到 Firebase
- 查看 `GoogleService-Info.plist` 是否正确放入

### Q2：如何获取 FCM Token？
```dart
String? token = await FirebaseMessaging.instance.getToken();
print('Token: $token');
```

### Q3：如何处理通知点击跳转？
在 `_handleNotificationTap` 方法中添加导航逻辑

### Q4：后台通知无法处理？
确保 `_firebaseMessagingBackgroundHandler` 是顶级函数（不在类中）

---

## 参考文档

- [FlutterFire Documentation](https://firebase.flutter.dev/docs/messaging/overview/)
- [Apple Push Notification Guide](https://developer.apple.com/documentation/usernotifications/)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)

---

**更新时间：2024年7月**
