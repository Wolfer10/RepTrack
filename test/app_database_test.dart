import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_track/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<({int squatId, int benchId, int routineId, int workoutId})> seedWorkoutFlow() async {
    final squatId = await db.exercisesRepo.createExercise('Barbell Squat');
    final benchId = await db.exercisesRepo.createExercise('Bench Press');
    final routineId = await db.routinesRepo.createRoutine('Push Day');

    await db.routinesRepo.addExerciseToRoutine(
      routineId,
      benchId,
      0,
      targetSets: 4,
      targetReps: 8,
    );
    await db.routinesRepo.addExerciseToRoutine(
      routineId,
      squatId,
      1,
      targetSets: 3,
      targetReps: 5,
    );

    final workoutId = await db.workoutsRepo.startWorkout(routineId);
    await db.workoutsRepo.addWorkoutSet(workoutId, benchId, 1, 8, 60.0, 90);
    await db.workoutsRepo.addWorkoutSet(workoutId, benchId, 2, 8, 62.5, 120);
    await db.workoutsRepo.addWorkoutSet(workoutId, squatId, 1, 5, 100.0, 150);
    await db.workoutsRepo.finishWorkout(workoutId);

    return (
      squatId: squatId,
      benchId: benchId,
      routineId: routineId,
      workoutId: workoutId,
    );
  }

  test('creates and lists routines ordered by name', () async {
    await db.routinesRepo.createRoutine('Push Day');
    await db.routinesRepo.createRoutine('Leg Day');

    final routines = await db.routinesRepo.getAllRoutines();

    expect(routines, hasLength(2));
    expect(routines.map((routine) => routine.name).toList(), [
      'Leg Day',
      'Push Day',
    ]);
  });

  test('returns routine exercises with joined exercise data in routine order', () async {
    final seeded = await seedWorkoutFlow();

    final routineWithExercises = await db.routinesRepo.getRoutineWithExercises(
      seeded.routineId,
    );

    expect(routineWithExercises, hasLength(2));
    expect(routineWithExercises.first.exercise.name, 'Bench Press');
    expect(routineWithExercises.first.routineExercise.targetSets, 4);
    expect(routineWithExercises.first.routineExercise.targetReps, 8);
    expect(routineWithExercises.last.exercise.name, 'Barbell Squat');
    expect(routineWithExercises.last.routineExercise.targetSets, 3);
    expect(routineWithExercises.last.routineExercise.targetReps, 5);
  });

  test('returns workout sets with exercise details ordered by exercise and set number', () async {
    final seeded = await seedWorkoutFlow();

    final workoutSets = await db.workoutsRepo.getWorkoutWithSets(
      seeded.workoutId,
    );

    expect(workoutSets, hasLength(3));
    expect(
      workoutSets.map((set) => set.exercise.name).toList(),
      ['Bench Press', 'Bench Press', 'Barbell Squat'],
    );
    expect(workoutSets.map((set) => set.workoutSet.setNumber).toList(), [
      1,
      2,
      1,
    ]);
    expect(workoutSets.first.workoutSet.weight, 60.0);
    expect(workoutSets[1].workoutSet.weight, 62.5);
    expect(workoutSets.last.workoutSet.weight, 100.0);
  });

  test('groups workout sets by exercise id', () async {
    final seeded = await seedWorkoutFlow();

    final groupedWorkoutSets = await db.workoutsRepo.getWorkoutWithGroupedSets(
      seeded.workoutId,
    );

    expect(groupedWorkoutSets.keys.toList(), [seeded.benchId, seeded.squatId]);
    expect(groupedWorkoutSets[seeded.benchId], hasLength(2));
    expect(groupedWorkoutSets[seeded.squatId], hasLength(1));
    expect(groupedWorkoutSets[seeded.benchId]!.last.workoutSet.weight, 62.5);
    expect(groupedWorkoutSets[seeded.squatId]!.single.workoutSet.reps, 5);
  });

  test('returns workout history for a routine with completed workouts first', () async {
    final seeded = await seedWorkoutFlow();

    final workoutHistory = await db.workoutsRepo.getWorkoutsForRoutine(
      seeded.routineId,
    );

    expect(workoutHistory, hasLength(1));
    expect(workoutHistory.single.routineId, seeded.routineId);
    expect(workoutHistory.single.endedAt, isNotNull);
  });
}
