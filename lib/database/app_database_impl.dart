part of app_database;

@DriftDatabase(
  tables: [Exercises, Routines, RoutineExercises, Workouts, WorkoutSets],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? openDatabaseConnection());

  late final ExerciseRepository exercisesRepo = ExerciseRepository(this);
  late final RoutineRepository routinesRepo = RoutineRepository(this);
  late final WorkoutRepository workoutsRepo = WorkoutRepository(this);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();

      await customStatement(
        'CREATE INDEX idx_routine_exercises_routine_order '
        'ON routine_exercises (routine_id, order_index)',
      );
      await customStatement(
        'CREATE INDEX idx_routine_exercises_exercise '
        'ON routine_exercises (exercise_id)',
      );
      await customStatement(
        'CREATE INDEX idx_workouts_routine_started '
        'ON workouts (routine_id, started_at DESC)',
      );
      await customStatement(
        'CREATE INDEX idx_workout_sets_workout '
        'ON workout_sets (workout_id)',
      );
      await customStatement(
        'CREATE INDEX idx_workout_sets_workout_exercise_set '
        'ON workout_sets (workout_id, exercise_id, set_number)',
      );
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await _seedTestDataIfEmpty();
    },
  );

  Future<void> _seedTestDataIfEmpty() async {
    final existingRoutine = await (select(routines)..limit(1)).getSingleOrNull();
    if (existingRoutine != null) {
      return;
    }

    await transaction(() async {
      final benchId = await into(exercises).insert(
        ExercisesCompanion.insert(name: 'Bench Press'),
      );
      final squatId = await into(exercises).insert(
        ExercisesCompanion.insert(name: 'Barbell Squat'),
      );
      final deadliftId = await into(exercises).insert(
        ExercisesCompanion.insert(name: 'Deadlift'),
      );
      final rowId = await into(exercises).insert(
        ExercisesCompanion.insert(name: 'Cable Row'),
      );
      final pressId = await into(exercises).insert(
        ExercisesCompanion.insert(name: 'Overhead Press'),
      );

      final strengthRoutineId = await into(routines).insert(
        RoutinesCompanion.insert(name: 'Full Body Strength'),
      );
      final upperRoutineId = await into(routines).insert(
        RoutinesCompanion.insert(name: 'Upper Body Focus'),
      );

      await into(routineExercises).insert(
        RoutineExercisesCompanion.insert(
          routineId: strengthRoutineId,
          exerciseId: squatId,
          orderIndex: 0,
          targetSets: const Value(3),
          targetReps: const Value(5),
        ),
      );
      await into(routineExercises).insert(
        RoutineExercisesCompanion.insert(
          routineId: strengthRoutineId,
          exerciseId: benchId,
          orderIndex: 1,
          targetSets: const Value(4),
          targetReps: const Value(6),
        ),
      );
      await into(routineExercises).insert(
        RoutineExercisesCompanion.insert(
          routineId: strengthRoutineId,
          exerciseId: rowId,
          orderIndex: 2,
          targetSets: const Value(3),
          targetReps: const Value(10),
        ),
      );
      await into(routineExercises).insert(
        RoutineExercisesCompanion.insert(
          routineId: upperRoutineId,
          exerciseId: pressId,
          orderIndex: 0,
          targetSets: const Value(4),
          targetReps: const Value(8),
        ),
      );
      await into(routineExercises).insert(
        RoutineExercisesCompanion.insert(
          routineId: upperRoutineId,
          exerciseId: rowId,
          orderIndex: 1,
          targetSets: const Value(4),
          targetReps: const Value(12),
        ),
      );
      await into(routineExercises).insert(
        RoutineExercisesCompanion.insert(
          routineId: upperRoutineId,
          exerciseId: deadliftId,
          orderIndex: 2,
          targetSets: const Value(3),
          targetReps: const Value(5),
        ),
      );

      final now = DateTime.now();
      await _insertSeedWorkout(
        routineId: strengthRoutineId,
        startedAt: now.subtract(const Duration(days: 8, hours: 2)),
        durationMinutes: 52,
        sets: [
          (exerciseId: squatId, reps: 5, weight: 90.0, setNumber: 1, rest: 150),
          (exerciseId: squatId, reps: 5, weight: 92.5, setNumber: 2, rest: 150),
          (exerciseId: squatId, reps: 5, weight: 95.0, setNumber: 3, rest: 180),
          (exerciseId: benchId, reps: 6, weight: 60.0, setNumber: 1, rest: 120),
          (exerciseId: benchId, reps: 6, weight: 62.5, setNumber: 2, rest: 120),
          (exerciseId: benchId, reps: 6, weight: 65.0, setNumber: 3, rest: 120),
          (exerciseId: rowId, reps: 10, weight: 42.5, setNumber: 1, rest: 90),
          (exerciseId: rowId, reps: 10, weight: 45.0, setNumber: 2, rest: 90),
        ],
      );
      await _insertSeedWorkout(
        routineId: upperRoutineId,
        startedAt: now.subtract(const Duration(days: 5, hours: 1)),
        durationMinutes: 47,
        sets: [
          (exerciseId: pressId, reps: 8, weight: 35.0, setNumber: 1, rest: 90),
          (exerciseId: pressId, reps: 8, weight: 35.0, setNumber: 2, rest: 90),
          (exerciseId: pressId, reps: 7, weight: 37.5, setNumber: 3, rest: 120),
          (exerciseId: rowId, reps: 12, weight: 40.0, setNumber: 1, rest: 90),
          (exerciseId: rowId, reps: 12, weight: 42.5, setNumber: 2, rest: 90),
          (exerciseId: deadliftId, reps: 5, weight: 110.0, setNumber: 1, rest: 180),
          (exerciseId: deadliftId, reps: 5, weight: 115.0, setNumber: 2, rest: 180),
        ],
      );
      await _insertSeedWorkout(
        routineId: strengthRoutineId,
        startedAt: now.subtract(const Duration(days: 2, hours: 3)),
        durationMinutes: 55,
        sets: [
          (exerciseId: squatId, reps: 5, weight: 97.5, setNumber: 1, rest: 150),
          (exerciseId: squatId, reps: 5, weight: 100.0, setNumber: 2, rest: 180),
          (exerciseId: squatId, reps: 4, weight: 102.5, setNumber: 3, rest: 180),
          (exerciseId: benchId, reps: 6, weight: 67.5, setNumber: 1, rest: 120),
          (exerciseId: benchId, reps: 6, weight: 67.5, setNumber: 2, rest: 120),
          (exerciseId: benchId, reps: 5, weight: 70.0, setNumber: 3, rest: 150),
          (exerciseId: rowId, reps: 10, weight: 47.5, setNumber: 1, rest: 90),
          (exerciseId: rowId, reps: 10, weight: 47.5, setNumber: 2, rest: 90),
        ],
      );
      await _insertSeedWorkout(
        routineId: upperRoutineId,
        startedAt: now.subtract(const Duration(days: 1, hours: 4)),
        durationMinutes: 44,
        sets: [
          (exerciseId: pressId, reps: 8, weight: 37.5, setNumber: 1, rest: 90),
          (exerciseId: pressId, reps: 8, weight: 37.5, setNumber: 2, rest: 90),
          (exerciseId: pressId, reps: 8, weight: 40.0, setNumber: 3, rest: 120),
          (exerciseId: rowId, reps: 12, weight: 45.0, setNumber: 1, rest: 90),
          (exerciseId: rowId, reps: 11, weight: 47.5, setNumber: 2, rest: 90),
          (exerciseId: deadliftId, reps: 5, weight: 120.0, setNumber: 1, rest: 180),
        ],
      );
    });
  }

  Future<void> _insertSeedWorkout({
    required int routineId,
    required DateTime startedAt,
    required int durationMinutes,
    required List<({
      int exerciseId,
      int reps,
      double weight,
      int setNumber,
      int rest,
    })> sets,
  }) async {
    final workoutId = await into(workouts).insert(
      WorkoutsCompanion.insert(
        routineId: routineId,
        startedAt: startedAt,
        endedAt: Value(startedAt.add(Duration(minutes: durationMinutes))),
      ),
    );

    for (final set in sets) {
      await into(workoutSets).insert(
        WorkoutSetsCompanion.insert(
          workoutId: workoutId,
          exerciseId: set.exerciseId,
          setNumber: set.setNumber,
          reps: set.reps,
          weight: set.weight,
          restSeconds: set.rest,
        ),
      );
    }
  }
}
