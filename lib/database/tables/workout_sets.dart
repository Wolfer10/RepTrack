part of app_database;

class WorkoutSets extends Table {
  @override
  String get tableName => 'workout_sets';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer()();
  RealColumn get weight => real()();
  IntColumn get restSeconds => integer()();
}
