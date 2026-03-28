import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rep_track/app/rep_track_app.dart';
import 'package:rep_track/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(RepTrackApp(database: AppDatabase()));
}
