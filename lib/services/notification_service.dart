import 'notification_io.dart';

class NotificationService {
  final NotificationIO _io = NotificationIO();
  String? _soundUri;

  Future<void> initialize() => _io.initialize();

  Future<void> requestPermission() => _io.requestPermission();

  Future<void> schedule({required String title, required String body, required DateTime date, String? soundUri}) =>
      _io.schedule(title: title, body: body, date: date, soundUri: soundUri);

  Future<void> cancelScheduled() => _io.cancelScheduled();

  void setSoundUri(String? uri) {
    _soundUri = uri;
  }

  Future<void> showNotification({required String title, required String body}) =>
      _io.show(title: title, body: body, soundUri: _soundUri);

  void cancelAll() => _io.cancelAll();
}
