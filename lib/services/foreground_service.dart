import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundService {
  static final ForegroundService _instance = ForegroundService._();
  static ForegroundService get instance => _instance;
  ForegroundService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'timer_channel',
        channelName: '\u8ba1\u65f6\u5668',
        channelDescription: '\u5b66\u4e60\u8ba1\u65f6\u5668\u540e\u53f0\u8fd0\u884c',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );

    _initialized = true;
  }

  Future<void> start() async {
    if (!_initialized) return;

    final running = await FlutterForegroundTask.isRunningService;
    if (running) return;

    await FlutterForegroundTask.startService(
      notificationTitle: '\u5b66\u4e60\u8ba1\u65f6\u5668',
      notificationText: '\u6b63\u5728\u8ba1\u65f6...',
    );
  }

  Future<void> stop() async {
    if (!_initialized) return;

    final running = await FlutterForegroundTask.isRunningService;
    if (!running) return;

    await FlutterForegroundTask.stopService();
  }
}
