import 'package:drift/drift.dart';

import 'connection_factory_native.dart'
    if (dart.library.js_interop) 'connection_factory_web.dart';

QueryExecutor createAppDatabaseConnection() {
  return createPlatformDatabaseConnection();
}
