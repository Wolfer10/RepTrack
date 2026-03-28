import 'package:flutter/material.dart';
import 'package:rep_track/app_database.dart';
import 'package:rep_track/features/routines/routines_home_page.dart';

class RepTrackApp extends StatelessWidget {
  const RepTrackApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC65D2B),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFFB74D1F),
      secondary: const Color(0xFF365B4C),
      surface: const Color(0xFFFFFAF5),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rep Track',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF7F0E8),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF22160F),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE9D8C9)),
          ),
        ),
      ),
      home: RoutinesHomePage(database: database),
    );
  }
}
