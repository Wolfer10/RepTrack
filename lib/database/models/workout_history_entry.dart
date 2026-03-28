part of app_database;

class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    required this.workout,
    required this.routine,
    required this.exerciseCount,
    required this.setCount,
  });

  final Workout workout;
  final Routine routine;
  final int exerciseCount;
  final int setCount;
}
