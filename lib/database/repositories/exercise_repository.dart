part of app_database;

class ExerciseRepository {
  const ExerciseRepository(this._db);

  final AppDatabase _db;

  Future<List<Exercise>> getAllExercises() {
    return (_db.select(_db.exercises)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<int> createExercise(String name) {
    return _db.into(
      _db.exercises,
    ).insert(ExercisesCompanion.insert(name: name));
  }

  Future<int> getOrCreateExercise(String name) async {
    final normalizedName = name.trim();
    final existing = await (_db.select(_db.exercises)
          ..where((t) => t.name.lower().equals(normalizedName.toLowerCase()))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    return createExercise(normalizedName);
  }
}
