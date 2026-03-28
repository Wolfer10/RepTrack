import 'package:flutter/material.dart';
import 'package:rep_track/app/rep_track_app.dart';
import 'package:rep_track/app_database.dart';

void main() {
  runApp(RepTrackApp(database: AppDatabase()));
}
