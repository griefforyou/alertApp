# Flutter iOS 本地通知（flutter_local_notifications）

## 调用流程

``` text
Flutter
    ↓
flutter_local_notifications
    ↓
DarwinNotificationDetails
    ↓
UNUserNotificationCenter
    ↓
iOS 通知中心
```

`flutter_local_notifications` 底层调用 iOS 原生
**UNUserNotificationCenter**，无需自行编写 Objective-C/Swift。

## 1. show() 调用 UNUserNotificationCenter

``` dart
await flutterLocalNotificationsPlugin.show(
  1,
  "标题",
  "内容",
  NotificationDetails(
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  ),
);
```

底层流程：

``` text
DarwinNotificationDetails
        ↓
UNMutableNotificationContent
        ↓
UNNotificationRequest
        ↓
UNUserNotificationCenter.add()
```

因此，**DarwinNotificationDetails 是 Flutter 对 iOS 通知配置的封装。**

## 2. 推荐封装 \_buildIosDetails()

``` dart
DarwinNotificationDetails _buildIosDetails() {
  return const DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.active,
  );
}
```

调用：

``` dart
await _plugin.show(
  id,
  title,
  body,
  NotificationDetails(
    iOS: _buildIosDetails(),
  ),
);
```

## 3. 初始化时申请通知权限

``` dart
await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        DarwinFlutterLocalNotificationsPlugin>()
    ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
```

如果用户拒绝权限：

-   `show()` 仍会执行；
-   但系统不会显示通知。

## 4. 前台通知默认不会显示

初始化：

``` dart
DarwinInitializationSettings(
  defaultPresentAlert: true,
  defaultPresentBadge: true,
  defaultPresentSound: true,
)
```

或每次通知：

``` dart
DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
)
```

否则前台调用 `show()` 也不会弹出通知。

## 5. 常用配置

``` dart
DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
  badgeNumber: 10,
  subtitle: "副标题",
  threadIdentifier: "chat",
  interruptionLevel: InterruptionLevel.timeSensitive,
  categoryIdentifier: "reply",
  attachments: [...],
  sound: "ding.aiff",
)
```

对应原生：

-   title
-   subtitle
-   body
-   badge
-   sound
-   categoryIdentifier
-   threadIdentifier
-   interruptionLevel
-   attachments

## 6. 什么时候需要原生开发

插件足以满足：

-   本地通知
-   定时通知
-   前台通知
-   Badge
-   Sound

需要原生开发的典型场景：

-   Notification Service Extension
-   Notification Content Extension
-   Live Activities
-   Critical Alerts
-   更深度的 iOS 通知框架集成

## 总结

推荐方案：

``` dart
DarwinNotificationDetails iosDetails = _buildIosDetails();

await _plugin.show(
  id,
  title,
  body,
  NotificationDetails(
    iOS: iosDetails,
  ),
);
```

最终由 `flutter_local_notifications` 转换为 `UNNotificationRequest`
并调用 `UNUserNotificationCenter` 显示通知。
