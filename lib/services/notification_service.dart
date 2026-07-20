import 'notification_io.dart';

class NotificationService {
  final NotificationIO _io = NotificationIO();
  String? _soundUri;

  Future<void> initialize() => _io.initialize();

  void setSoundUri(String? uri) {
    _soundUri = uri;
  }

  Future<void> showNotification({required String title, required String body}) =>
      _io.show(title: title, body: body, soundUri: _soundUri);

  void cancelAll() => _io.cancelAll();
}
