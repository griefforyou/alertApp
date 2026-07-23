class StorageIO {
  Future<String> get documentsPath async => '(stub)';
  Future<String?> readString(String key) async => null;
  Future<void> writeString(String key, String value) async {}
  Future<bool> exists(String key) async => false;
  Future<void> delete(String key) async {}
}
