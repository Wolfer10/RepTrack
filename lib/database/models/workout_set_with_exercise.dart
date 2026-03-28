part of app_database;

class WorkoutSetWithExercise {
  const WorkoutSetWithExercise({
    required this.workoutSet,
    required this.exercise,
  });

  final WorkoutSet workoutSet;
  final Exercise exercise;
}
