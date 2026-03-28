part of app_database;

class WorkoutRepository {
  const WorkoutRepository(this._db);

  final AppDatabase _db;

  Future<int> startWorkout(int routineId) {
    return _db.into(_db.workouts).insert(
      WorkoutsCompanion.insert(
        routineId: routineId,
        startedAt: DateTime.now(),
      ),
    );
  }

  Future<void> finishWorkout(int workoutId) async {
    await (_db.update(_db.workouts)..where((t) => t.id.equals(workoutId))).write(
      WorkoutsCompanion(endedAt: Value(DateTime.now())),
    );
  }

  Future<int> addWorkoutSet(
    int workoutId,
    int exerciseId,
    int setNumber,
    int reps,
    double weight,
    int restSeconds,
  ) {
    return _db.into(_db.workoutSets).insert(
      WorkoutSetsCompanion.insert(
        workoutId: workoutId,
        exerciseId: exerciseId,
        setNumber: setNumber,
        reps: reps,
        weight: weight,
        restSeconds: restSeconds,
      ),
    );
  }

  Future<List<WorkoutSetWithExercise>> getWorkoutWithSets(int workoutId) async {
    final query = _db.select(_db.workoutSets).join([
      innerJoin(
        _db.workouts,
        _db.workouts.id.equalsExp(_db.workoutSets.workoutId),
      ),
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.workoutSets.exerciseId),
      ),
      innerJoin(
        _db.routineExercises,
        _db.routineExercises.routineId.equalsExp(_db.workouts.routineId) &
            _db.routineExercises.exerciseId.equalsExp(_db.workoutSets.exerciseId),
      ),
    ])
      ..where(_db.workoutSets.workoutId.equals(workoutId))
      ..orderBy([
        OrderingTerm.asc(_db.routineExercises.orderIndex),
        OrderingTerm.asc(_db.workoutSets.setNumber),
        OrderingTerm.asc(_db.workoutSets.id),
      ]);

    final rows = await query.get();

    return rows
        .map(
          (row) => WorkoutSetWithExercise(
            workoutSet: row.readTable(_db.workoutSets),
            exercise: row.readTable(_db.exercises),
          ),
        )
        .toList();
  }

  Future<List<WorkoutSessionExercise>> getWorkoutSessionExercises(
    int workoutId,
  ) async {
    final workout = await (_db.select(_db.workouts)
          ..where((t) => t.id.equals(workoutId)))
        .getSingle();
    final routineExercises = await _db.routinesRepo.getRoutineWithExercises(
      workout.routineId,
    );
    final groupedSets = await getWorkoutWithGroupedSets(workoutId);

    return routineExercises
        .map(
          (entry) => WorkoutSessionExercise(
            routineExercise: entry.routineExercise,
            exercise: entry.exercise,
            loggedSets: groupedSets[entry.exercise.id] ?? const [],
          ),
        )
        .toList();
  }

  Future<Map<int, List<WorkoutSetWithExercise>>> getWorkoutWithGroupedSets(
    int workoutId,
  ) async {
    final flatRows = await getWorkoutWithSets(workoutId);
    final grouped = <int, List<WorkoutSetWithExercise>>{};

    for (final row in flatRows) {
      grouped.putIfAbsent(row.exercise.id, () => <WorkoutSetWithExercise>[]);
      grouped[row.exercise.id]!.add(row);
    }

    return grouped;
  }

  Future<List<WorkoutSet>> getLatestSetsForExercise(
    int exerciseId, {
    int? excludeWorkoutId,
  }) async {
    final recentWorkoutQuery = _db.select(_db.workoutSets).join([
      innerJoin(
        _db.workouts,
        _db.workouts.id.equalsExp(_db.workoutSets.workoutId),
      ),
    ])
      ..where(_db.workoutSets.exerciseId.equals(exerciseId))
      ..where(_db.workouts.endedAt.isNotNull())
      ..orderBy([
        OrderingTerm.desc(_db.workouts.startedAt),
        OrderingTerm.desc(_db.workoutSets.id),
      ])
      ..limit(20);

    final recentRows = await recentWorkoutQuery.get();
    int? recentWorkoutId;
    for (final row in recentRows) {
      final candidateWorkoutId = row.readTable(_db.workoutSets).workoutId;
      if (candidateWorkoutId != excludeWorkoutId) {
        recentWorkoutId = candidateWorkoutId;
        break;
      }
    }

    if (recentWorkoutId == null) {
      return [];
    }

    return (_db.select(_db.workoutSets)
          ..where(
            (t) => t.workoutId.equals(recentWorkoutId!) & t.exerciseId.equals(exerciseId),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.setNumber),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<List<Workout>> getWorkoutsForRoutine(int routineId) {
    return (_db.select(_db.workouts)
          ..where((t) => t.routineId.equals(routineId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<List<WorkoutHistoryEntry>> getCompletedWorkoutHistory() async {
    final workoutsQuery = _db.select(_db.workouts).join([
      innerJoin(
        _db.routines,
        _db.routines.id.equalsExp(_db.workouts.routineId),
      ),
    ])
      ..where(_db.workouts.endedAt.isNotNull())
      ..orderBy([
        OrderingTerm.desc(_db.workouts.startedAt),
        OrderingTerm.desc(_db.workouts.id),
      ]);

    final workoutRows = await workoutsQuery.get();
    final history = <WorkoutHistoryEntry>[];

    for (final row in workoutRows) {
      final workout = row.readTable(_db.workouts);
      final routine = row.readTable(_db.routines);
      final sets = await (_db.select(_db.workoutSets)
            ..where((t) => t.workoutId.equals(workout.id)))
          .get();
      history.add(
        WorkoutHistoryEntry(
          workout: workout,
          routine: routine,
          exerciseCount: sets.map((set) => set.exerciseId).toSet().length,
          setCount: sets.length,
        ),
      );
    }

    return history;
  }
}
