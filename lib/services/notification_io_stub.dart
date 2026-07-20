class NotificationIO {
  Future<void> initialize() async {}
  Future<void> show({required String title, required String body, String? soundUri}) async {}
  void cancelAll() {}
}
