import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rep_track/app_database.dart';
import 'package:rep_track/shared/formatters.dart';

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({
    super.key,
    required this.database,
    required this.workoutId,
    required this.routine,
    required this.startedAt,
  });

  final AppDatabase database;
  final int workoutId;
  final Routine routine;
  final DateTime startedAt;

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  DateTime? _restEndsAt;
  int? _restInitialSeconds;
  String? _restLabel;
  bool _loading = true;
  bool _finishing = false;
  List<WorkoutSessionExercise> _sessionExercises = const [];
  Map<int, List<WorkoutSet>> _previousSetsByExercise = const {};

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    _refreshSession();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _elapsed => _now.difference(widget.startedAt);

  Duration? get _restRemaining {
    if (_restEndsAt == null) {
      return null;
    }
    final remaining = _restEndsAt!.difference(_now);
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  Future<void> _refreshSession() async {
    final exercises = await widget.database.workoutsRepo.getWorkoutSessionExercises(
      widget.workoutId,
    );
    final previousSetsByExercise = <int, List<WorkoutSet>>{};
    for (final exercise in exercises) {
      previousSetsByExercise[exercise.exercise.id] =
          await widget.database.workoutsRepo.getLatestSetsForExercise(
        exercise.exercise.id,
        excludeWorkoutId: widget.workoutId,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _sessionExercises = exercises;
      _previousSetsByExercise = previousSetsByExercise;
      _loading = false;
    });
  }

  Future<void> _finishWorkout() async {
    setState(() => _finishing = true);
    await widget.database.workoutsRepo.finishWorkout(widget.workoutId);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _addExerciseToWorkout() async {
    final draft = await showDialog<_QuickRoutineExerciseResult>(
      context: context,
      builder: (_) => const _QuickRoutineExerciseDialog(),
    );
    if (draft == null) {
      return;
    }

    final exerciseId = await widget.database.exercisesRepo.getOrCreateExercise(
      draft.name,
    );
    await widget.database.routinesRepo.appendExerciseToRoutine(
      widget.routine.id,
      exerciseId,
      targetSets: draft.targetSets,
      targetReps: draft.targetReps,
    );
    await _refreshSession();
  }

  Future<void> _openExerciseSheet(WorkoutSessionExercise item) async {
    final previousSets = _previousSetsByExercise[item.exercise.id] ?? const [];

    if (!mounted) {
      return;
    }

    final result = await showModalBottomSheet<_SetEntryResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExerciseLogSheet(
        item: item,
        previousSets: previousSets,
      ),
    );

    if (result == null) {
      return;
    }

    await widget.database.workoutsRepo.addWorkoutSet(
      widget.workoutId,
      item.exercise.id,
      item.loggedSets.length + 1,
      result.reps,
      result.weight,
      result.restSeconds,
    );

    if (!mounted) {
      return;
    }

    if (result.restSeconds > 0) {
      setState(() {
        _restEndsAt = DateTime.now().add(Duration(seconds: result.restSeconds));
        _restInitialSeconds = result.restSeconds;
        _restLabel = item.exercise.name;
      });
    }

    await _refreshSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _finishing ? null : _finishWorkout,
              child: Text(_finishing ? 'Finishing...' : 'Finish'),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF3E0C9),
              Color(0xFFF7F0E8),
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    _WorkoutStatusCard(
                      elapsed: _elapsed,
                      startedAt: widget.startedAt,
                      restRemaining: _restRemaining,
                      restLabel: _restLabel,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Today\'s exercises',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _addExerciseToWorkout,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add exercise'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_sessionExercises.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'No exercises yet. Add one if your plan changed.',
                                ),
                              )
                            else
                              ..._sessionExercises.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _WorkoutExerciseCard(
                                    item: item,
                                    previousSets:
                                        _previousSetsByExercise[item.exercise.id] ??
                                        const [],
                                    onTap: () => _openExerciseSheet(item),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: _RestTimerBar(
        restRemaining: _restRemaining,
        restInitialSeconds: _restInitialSeconds,
        restLabel: _restLabel,
        onAddSeconds: (seconds) {
          if (_restEndsAt == null) {
            return;
          }
          setState(() {
            _restEndsAt = _restEndsAt!.add(Duration(seconds: seconds));
            _restInitialSeconds = (_restInitialSeconds ?? 0) + seconds;
          });
        },
        onSkip: () {
          setState(() {
            _restEndsAt = null;
            _restInitialSeconds = null;
            _restLabel = null;
          });
        },
      ),
    );
  }
}

class ExerciseLogSheet extends StatefulWidget {
  const ExerciseLogSheet({
    super.key,
    required this.item,
    required this.previousSets,
  });

  final WorkoutSessionExercise item;
  final List<WorkoutSet> previousSets;

  @override
  State<ExerciseLogSheet> createState() => _ExerciseLogSheetState();
}

class _ExerciseLogSheetState extends State<ExerciseLogSheet> {
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;
  late final TextEditingController _restMinutesController;

  @override
  void initState() {
    super.initState();
    final lastSet = widget.item.loggedSets.isNotEmpty
        ? widget.item.loggedSets.last.workoutSet
        : widget.previousSets.isNotEmpty
            ? widget.previousSets.last
            : null;

    _repsController = TextEditingController(
      text: lastSet?.reps.toString() ??
          widget.item.routineExercise.targetReps?.toString() ??
          '',
    );
    _weightController = TextEditingController(
      text: lastSet == null ? '' : formatWeightNumber(lastSet.weight),
    );
    _restMinutesController = TextEditingController(
      text: lastSet != null && lastSet.restSeconds > 0
          ? (lastSet.restSeconds ~/ 60).toString()
          : '2',
    );
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    _restMinutesController.dispose();
    super.dispose();
  }

  void _submit() {
    final reps = int.tryParse(_repsController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final restMinutes = int.tryParse(_restMinutesController.text.trim()) ?? 0;

    if (reps == null || weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add valid reps and weight.')),
      );
      return;
    }

    Navigator.of(context).pop(
      _SetEntryResult(
        reps: reps,
        weight: weight,
        restSeconds: restMinutes * 60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSets = widget.item.loggedSets;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.exercise.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap save after each set. Your rest timer starts automatically.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          if (widget.previousSets.isNotEmpty) ...[
            _SectionLabel(
              label: 'Last workout',
              detail: buildSetSummary(widget.previousSets),
            ),
            const SizedBox(height: 14),
          ],
          _SectionLabel(
            label: 'Logged now',
            detail: currentSets.isEmpty
                ? 'No sets logged yet'
                : buildSetSummary(
                    currentSets.map((item) => item.workoutSet).toList(),
                  ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _restMinutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Rest minutes'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final minutes in [1, 2, 3])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: () => _restMinutesController.text = '$minutes',
                    child: Text('${minutes}m'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text('Save set ${currentSets.length + 1}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutStatusCard extends StatelessWidget {
  const _WorkoutStatusCard({
    required this.elapsed,
    required this.startedAt,
    required this.restRemaining,
    required this.restLabel,
  });

  final Duration elapsed;
  final DateTime startedAt;
  final Duration? restRemaining;
  final String? restLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout in progress',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricPill(
                  label: 'Elapsed',
                  value: formatDuration(elapsed),
                  color: const Color(0xFFF4CDAA),
                ),
                _MetricPill(
                  label: 'Started',
                  value: formatTimeOfDay(startedAt),
                  color: const Color(0xFFDCE7DF),
                ),
                _MetricPill(
                  label: 'Rest',
                  value: restRemaining == null
                      ? 'Ready'
                      : restRemaining == Duration.zero
                          ? 'Go'
                          : formatDuration(restRemaining!),
                  color: const Color(0xFFE6D6EF),
                ),
              ],
            ),
            if (restLabel != null && restRemaining != null) ...[
              const SizedBox(height: 12),
              Text(
                restRemaining == Duration.zero
                    ? 'Rest complete for $restLabel'
                    : 'Resting after $restLabel',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RestTimerBar extends StatelessWidget {
  const _RestTimerBar({
    required this.restRemaining,
    required this.restInitialSeconds,
    required this.restLabel,
    required this.onAddSeconds,
    required this.onSkip,
  });

  final Duration? restRemaining;
  final int? restInitialSeconds;
  final String? restLabel;
  final ValueChanged<int> onAddSeconds;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    if (restRemaining == null || restLabel == null) {
      return const SizedBox.shrink();
    }

    final remainingSeconds = restRemaining!.inSeconds;
    final initialSeconds = (restInitialSeconds ?? remainingSeconds).clamp(1, 86400);
    final progress = remainingSeconds == 0
        ? 1.0
        : 1 - (remainingSeconds / initialSeconds);
    final complete = restRemaining == Duration.zero;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: complete ? const Color(0xFF355D4D) : const Color(0xFF251A14),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complete ? 'Rest complete' : 'Resting after $restLabel',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          complete ? 'Go for the next set.' : formatDuration(restRemaining!),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: onSkip,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF251A14),
                    ),
                    child: Text(complete ? 'Dismiss' : 'Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: const Color(0x33FFFFFF),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    complete ? const Color(0xFFC8F0D7) : const Color(0xFFF6C36C),
                  ),
                ),
              ),
              if (!complete) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => onAddSeconds(30),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x55FFFFFF)),
                      ),
                      child: const Text('+30s'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => onAddSeconds(60),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x55FFFFFF)),
                      ),
                      child: const Text('+1 min'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutExerciseCard extends StatelessWidget {
  const _WorkoutExerciseCard({
    required this.item,
    required this.previousSets,
    required this.onTap,
  });

  final WorkoutSessionExercise item;
  final List<WorkoutSet> previousSets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCFA),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFD4B79F),
            width: 1.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12A05D34),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.exercise.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF21150F),
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E0CF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE0C2A7)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Log',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7B3E1B),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFF7B3E1B),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7EFE7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8D6C8)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: Color(0xFF8A5A39),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5D4334),
                        ),
                        children: [
                          const TextSpan(
                            text: 'Target: ',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: item.routineExercise.targetSets != null ||
                                    item.routineExercise.targetReps != null
                                ? '${item.routineExercise.targetSets ?? '-'} sets x ${item.routineExercise.targetReps ?? '-'} reps'
                                : 'No target set yet',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (previousSets.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF6F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5D4C5)),
                ),
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6F5A4D),
                      height: 1.35,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Last workout: ',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: buildSetSummary(previousSets)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (item.loggedSets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEAD7C5)),
                ),
                child: Text(
                  'No sets logged yet. Tap Log to add the first set.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6F5A4D),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4FAF6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC8DDCF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logged this workout',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF294537),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.loggedSets
                          .map(
                            (set) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFBFD8C7),
                                ),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF294537),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'S${set.workoutSet.setNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          '  ${set.workoutSet.reps} reps  ${formatWeight(set.workoutSet.weight)}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.detail,
  });

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7D7C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(detail),
        ],
      ),
    );
  }
}

class _QuickRoutineExerciseDialog extends StatefulWidget {
  const _QuickRoutineExerciseDialog();

  @override
  State<_QuickRoutineExerciseDialog> createState() =>
      _QuickRoutineExerciseDialogState();
}

class _QuickRoutineExerciseDialogState extends State<_QuickRoutineExerciseDialog> {
  final _nameController = TextEditingController();
  final _targetSetsController = TextEditingController();
  final _targetRepsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _targetSetsController.dispose();
    _targetRepsController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _QuickRoutineExerciseResult(
        name: name,
        targetSets: parseIntOrNull(_targetSetsController.text),
        targetReps: parseIntOrNull(_targetRepsController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Exercise name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _targetSetsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target sets'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _targetRepsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target reps'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _QuickRoutineExerciseResult {
  const _QuickRoutineExerciseResult({
    required this.name,
    this.targetSets,
    this.targetReps,
  });

  final String name;
  final int? targetSets;
  final int? targetReps;
}

class _SetEntryResult {
  const _SetEntryResult({
    required this.reps,
    required this.weight,
    required this.restSeconds,
  });

  final int reps;
  final double weight;
  final int restSeconds;
}
