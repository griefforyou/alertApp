class NotificationIO {
  Future<void> requestPermission() async {} 

  Future<void> initialize() async {}
  Future<void> show({required String title, required String body, String? soundUri}) async {}
  void cancelAll() {}
}
