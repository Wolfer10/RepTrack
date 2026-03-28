import 'package:flutter/material.dart';
import 'package:rep_track/app_database.dart';
import 'package:rep_track/features/routines/routine_editor_page.dart';
import 'package:rep_track/features/workouts/workout_history_page.dart';
import 'package:rep_track/features/workouts/workout_session_page.dart';

class RoutinesHomePage extends StatefulWidget {
  const RoutinesHomePage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<RoutinesHomePage> createState() => _RoutinesHomePageState();
}

class _RoutinesHomePageState extends State<RoutinesHomePage> {
  bool _loading = true;
  String? _errorMessage;
  List<_RoutineOverview> _routines = const [];

  @override
  void initState() {
    super.initState();
    _refreshRoutines();
  }

  Future<void> _refreshRoutines() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final routines = await widget.database.routinesRepo.getAllRoutines();
      final items = <_RoutineOverview>[];
      for (final routine in routines) {
        final exercises =
            await widget.database.routinesRepo.getRoutineWithExercises(
          routine.id,
        );
        items.add(_RoutineOverview(routine: routine, exercises: exercises));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _routines = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _openRoutineEditor([Routine? routine]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineEditorPage(
          database: widget.database,
          routine: routine,
        ),
      ),
    );
    await _refreshRoutines();
  }

  Future<void> _deleteRoutine(_RoutineOverview item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text(
          'This removes "${item.routine.name}" and all of its workout history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB33A2F),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await widget.database.routinesRepo.deleteRoutine(item.routine.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${item.routine.name}" deleted')),
    );
    await _refreshRoutines();
  }

  Future<void> _startWorkout(_RoutineOverview item) async {
    if (item.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one exercise before starting a workout.'),
        ),
      );
      return;
    }

    final startedAt = DateTime.now();
    final workoutId = await widget.database.workoutsRepo.startWorkout(
      item.routine.id,
    );
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutSessionPage(
          database: widget.database,
          workoutId: workoutId,
          routine: item.routine,
          startedAt: startedAt,
        ),
      ),
    );
    await _refreshRoutines();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutHistoryPage(database: widget.database),
      ),
    );
    await _refreshRoutines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines'),
        actions: [
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'History',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRoutineEditor(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New routine'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6E3D3),
              Color(0xFFF7F0E8),
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshRoutines,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              children: [
                _HeaderPanel(routineCount: _routines.length),
                const SizedBox(height: 20),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage != null)
                  _LoadErrorState(
                    message: _errorMessage!,
                    onRetry: _refreshRoutines,
                  )
                else if (_routines.isEmpty)
                  const _EmptyRoutineState()
                else
                  ..._routines.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _RoutineCard(
                        item: item,
                        onEdit: () => _openRoutineEditor(item.routine),
                        onDelete: () => _deleteRoutine(item),
                        onStart: () => _startWorkout(item),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Database failed to load',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(message),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({required this.routineCount});

  final int routineCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E5144),
            Color(0xFF486D5E),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rep Track',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Build routines, tweak them on the fly, and keep each workout easy to continue.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFF6E8D9),
                ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x24FFFFFF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '$routineCount ${routineCount == 1 ? 'routine' : 'routines'} ready',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoutineState extends StatelessWidget {
  const _EmptyRoutineState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No routines yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            const Text(
              'Create your first routine with a few exercises, then start a workout straight from the list.',
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
  });

  final _RoutineOverview item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.routine.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.exercises.length} ${item.exercises.length == 1 ? 'exercise' : 'exercises'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF7B6558),
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.exercises.isEmpty
                  ? const [
                      Chip(label: Text('Add exercises to start')),
                    ]
                  : item.exercises
                      .map(
                        (entry) => Chip(
                          label: Text(
                            entry.routineExercise.targetSets != null ||
                                    entry.routineExercise.targetReps != null
                                ? '${entry.exercise.name} - ${entry.routineExercise.targetSets ?? '-'} x ${entry.routineExercise.targetReps ?? '-'}'
                                : entry.exercise.name,
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineOverview {
  const _RoutineOverview({
    required this.routine,
    required this.exercises,
  });

  final Routine routine;
  final List<RoutineExerciseWithExercise> exercises;
}
