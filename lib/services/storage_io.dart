export 'storage_io_stub.dart'
  if (dart.library.io) 'storage_io_native.dart'
  if (dart.library.html) 'storage_io_web.dart';
