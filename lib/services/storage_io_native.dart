import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageIO {
  Future<Directory> get _dir => getApplicationDocumentsDirectory();

  Future<String> get documentsPath async => (await _dir).path;

  Future<String?> readString(String key) async {
    final dir = await _dir;
    final file = File('${dir.path}/$key');
    if (!await file.exists()) return null;
    return await file.readAsString();
  }

  Future<void> writeString(String key, String value) async {
    final dir = await _dir;
    final file = File('${dir.path}/$key');
    await file.writeAsString(value);
  }

  Future<bool> exists(String key) async {
    final dir = await _dir;
    final file = File('${dir.path}/$key');
    return await file.exists();
  }

  Future<void> delete(String key) async {
    final dir = await _dir;
    final file = File('${dir.path}/$key');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
