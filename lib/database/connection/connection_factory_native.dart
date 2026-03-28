import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

QueryExecutor createPlatformDatabaseConnection() {
  return driftDatabase(name: 'rep_track');
}
