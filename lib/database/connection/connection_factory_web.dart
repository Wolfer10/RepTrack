import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

QueryExecutor createPlatformDatabaseConnection() {
  return DatabaseConnection(
    LazyDatabase(() async {
      const databaseName = 'rep_track';
      final sqlite3 = await WasmSqlite3.loadFromUrl(
        Uri.parse('sqlite3.wasm'),
      );
      final fileSystem = await IndexedDbFileSystem.open(dbName: databaseName);
      sqlite3.registerVirtualFileSystem(fileSystem, makeDefault: true);
      return WasmDatabase(
        sqlite3: sqlite3,
        path: databaseName,
        fileSystem: fileSystem,
      );
    }),
  );
}
