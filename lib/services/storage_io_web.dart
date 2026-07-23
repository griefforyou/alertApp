import 'dart:html' show window;

class StorageIO {
  Future<String> get documentsPath async => 'web:localStorage';

  Future<String?> readString(String key) async {
    return window.localStorage[key];
  }

  Future<void> writeString(String key, String value) async {
    window.localStorage[key] = value;
  }

  Future<bool> exists(String key) async {
    return window.localStorage.containsKey(key);
  }

  Future<void> delete(String key) async {
    window.localStorage.remove(key);
  }
}
