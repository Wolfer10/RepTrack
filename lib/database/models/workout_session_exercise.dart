part of app_database;

class WorkoutSessionExercise {
  const WorkoutSessionExercise({
    required this.routineExercise,
    required this.exercise,
    required this.loggedSets,
  });

  final RoutineExercise routineExercise;
  final Exercise exercise;
  final List<WorkoutSetWithExercise> loggedSets;
}
