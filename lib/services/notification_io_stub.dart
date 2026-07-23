class NotificationIO {
  Future<void> requestPermission() async {}

  Future<void> initialize() async {}
  Future<void> show({required String title, required String body, String? soundUri}) async {}
  Future<void> schedule({required String title, required String body, required DateTime date, String? soundUri}) async {}
  Future<void> cancelScheduled() async {}
  void cancelAll() {}
}
