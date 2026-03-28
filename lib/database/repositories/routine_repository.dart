part of app_database;

class RoutineRepository {
  const RoutineRepository(this._db);

  final AppDatabase _db;

  Future<int> createRoutine(String name) {
    return _db.into(_db.routines).insert(RoutinesCompanion.insert(name: name));
  }

  Future<void> updateRoutine(int routineId, String name) {
    return (_db.update(_db.routines)..where((t) => t.id.equals(routineId))).write(
      RoutinesCompanion(name: Value(name.trim())),
    );
  }

  Future<int> addExerciseToRoutine(
    int routineId,
    int exerciseId,
    int orderIndex, {
    int? targetSets,
    int? targetReps,
  }) {
    return _db.into(_db.routineExercises).insert(
      RoutineExercisesCompanion.insert(
        routineId: routineId,
        exerciseId: exerciseId,
        orderIndex: orderIndex,
        targetSets: Value(targetSets),
        targetReps: Value(targetReps),
      ),
    );
  }

  Future<int> appendExerciseToRoutine(
    int routineId,
    int exerciseId, {
    int? targetSets,
    int? targetReps,
  }) async {
    final existing = await getRoutineWithExercises(routineId);
    return addExerciseToRoutine(
      routineId,
      exerciseId,
      existing.length,
      targetSets: targetSets,
      targetReps: targetReps,
    );
  }

  Future<void> updateRoutineExercise({
    required int routineExerciseId,
    required int exerciseId,
    required int orderIndex,
    int? targetSets,
    int? targetReps,
  }) {
    return (_db.update(_db.routineExercises)
          ..where((t) => t.id.equals(routineExerciseId)))
        .write(
          RoutineExercisesCompanion(
            exerciseId: Value(exerciseId),
            orderIndex: Value(orderIndex),
            targetSets: Value(targetSets),
            targetReps: Value(targetReps),
          ),
        );
  }

  Future<void> removeRoutineExercise(int routineExerciseId) async {
    final removed = await (_db.select(_db.routineExercises)
          ..where((t) => t.id.equals(routineExerciseId)))
        .getSingleOrNull();
    if (removed == null) {
      return;
    }

    await (_db.delete(_db.routineExercises)
          ..where((t) => t.id.equals(routineExerciseId)))
        .go();
    await _normalizeRoutineExerciseOrder(removed.routineId);
  }

  Future<void> saveRoutineExercises(
    int routineId,
    List<({
      int? id,
      int exerciseId,
      int orderIndex,
      int? targetSets,
      int? targetReps,
    })> entries,
  ) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.routineExercises)
            ..where((t) => t.routineId.equals(routineId)))
          .get();
      final incomingIds = entries
          .where((entry) => entry.id != null)
          .map((entry) => entry.id!)
          .toSet();

      for (final row in existing) {
        if (!incomingIds.contains(row.id)) {
          await (_db.delete(_db.routineExercises)
                ..where((t) => t.id.equals(row.id)))
              .go();
        }
      }

      for (final entry in entries) {
        if (entry.id == null) {
          await _db.into(_db.routineExercises).insert(
                RoutineExercisesCompanion.insert(
                  routineId: routineId,
                  exerciseId: entry.exerciseId,
                  orderIndex: entry.orderIndex,
                  targetSets: Value(entry.targetSets),
                  targetReps: Value(entry.targetReps),
                ),
              );
        } else {
          await (_db.update(_db.routineExercises)
                ..where((t) => t.id.equals(entry.id!)))
              .write(
                RoutineExercisesCompanion(
                  exerciseId: Value(entry.exerciseId),
                  orderIndex: Value(entry.orderIndex),
                  targetSets: Value(entry.targetSets),
                  targetReps: Value(entry.targetReps),
                ),
              );
        }
      }
    });
  }

  Future<void> deleteRoutine(int routineId) async {
    await _db.transaction(() async {
      final workoutIds = await (_db.selectOnly(_db.workouts)
            ..addColumns([_db.workouts.id])
            ..where(_db.workouts.routineId.equals(routineId)))
          .map((row) => row.read(_db.workouts.id))
          .get();

      if (workoutIds.isNotEmpty) {
        await (_db.delete(_db.workoutSets)
              ..where((t) => t.workoutId.isIn(workoutIds.whereType<int>())))
            .go();
        await (_db.delete(_db.workouts)
              ..where((t) => t.id.isIn(workoutIds.whereType<int>())))
            .go();
      }

      await (_db.delete(_db.routineExercises)
            ..where((t) => t.routineId.equals(routineId)))
          .go();
      await (_db.delete(_db.routines)..where((t) => t.id.equals(routineId))).go();
    });
  }

  Future<List<Routine>> getAllRoutines() {
    return (_db.select(_db.routines)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<List<RoutineExerciseWithExercise>> getRoutineWithExercises(
    int routineId,
  ) async {
    final query = _db.select(_db.routineExercises).join([
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.routineExercises.exerciseId),
      ),
    ])
      ..where(_db.routineExercises.routineId.equals(routineId))
      ..orderBy([
        OrderingTerm.asc(_db.routineExercises.orderIndex),
        OrderingTerm.asc(_db.routineExercises.id),
      ]);

    final rows = await query.get();

    return rows
        .map(
          (row) => RoutineExerciseWithExercise(
            routineExercise: row.readTable(_db.routineExercises),
            exercise: row.readTable(_db.exercises),
          ),
        )
        .toList();
  }

  Future<void> _normalizeRoutineExerciseOrder(int routineId) async {
    final rows = await getRoutineWithExercises(routineId);
    for (var index = 0; index < rows.length; index++) {
      final routineExercise = rows[index].routineExercise;
      if (routineExercise.orderIndex != index) {
        await (_db.update(_db.routineExercises)
              ..where((t) => t.id.equals(routineExercise.id)))
            .write(
              RoutineExercisesCompanion(orderIndex: Value(index)),
            );
      }
    }
  }
}
