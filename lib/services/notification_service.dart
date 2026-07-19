import 'notification_io.dart';

class NotificationService {
  final NotificationIO _io = NotificationIO();

  Future<void> initialize() => _io.initialize();

  Future<void> showNotification({required String title, required String body}) =>
      _io.show(title: title, body: body);

  void cancelAll() => _io.cancelAll();
}
