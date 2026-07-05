import 'package:flutter/material.dart';
import 'package:rep_track/app_database.dart';
import 'package:rep_track/shared/formatters.dart';

class RoutineEditorPage extends StatefulWidget {
  const RoutineEditorPage({
    super.key,
    required this.database,
    this.routine,
  });

  final AppDatabase database;
  final Routine? routine;

  bool get isEditing => routine != null;

  @override
  State<RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends State<RoutineEditorPage> {
  late final TextEditingController _nameController;
  final List<_RoutineExerciseDraft> _exerciseDrafts = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.routine?.name ?? '');
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    if (widget.routine != null) {
      final existing = await widget.database.routinesRepo.getRoutineWithExercises(
        widget.routine!.id,
      );
      for (final item in existing) {
        _exerciseDrafts.add(_RoutineExerciseDraft.fromExisting(item));
      }
    }

    if (_exerciseDrafts.isEmpty) {
      _exerciseDrafts.add(_RoutineExerciseDraft.empty());
    }

    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final draft in _exerciseDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addExerciseDraft() {
    setState(() {
      _exerciseDrafts.add(_RoutineExerciseDraft.empty());
    });
  }

  void _moveDraft(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _exerciseDrafts.length) {
      return;
    }

    setState(() {
      final item = _exerciseDrafts.removeAt(oldIndex);
      _exerciseDrafts.insert(newIndex, item);
    });
  }

  void _removeDraft(int index) {
    if (_exerciseDrafts.length == 1) {
      _exerciseDrafts[index].clear();
      setState(() {});
      return;
    }

    setState(() {
      final removed = _exerciseDrafts.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _saveRoutine() async {
    final routineName = _nameController.text.trim();
    if (routineName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your routine a name first.')),
      );
      return;
    }

    final filledDrafts = _exerciseDrafts
        .where((draft) => draft.nameController.text.trim().isNotEmpty)
        .toList();

    setState(() => _saving = true);
    try {
      final routineId = widget.routine?.id ??
          await widget.database.routinesRepo.createRoutine(routineName);

      if (widget.routine != null) {
        await widget.database.routinesRepo.updateRoutine(routineId, routineName);
      }

      final entries = <({
        int? id,
        int exerciseId,
        int orderIndex,
        int? targetSets,
        int? targetReps,
      })>[];

      for (var index = 0; index < filledDrafts.length; index++) {
        final draft = filledDrafts[index];
        final exerciseId = await widget.database.exercisesRepo.getOrCreateExercise(
          draft.nameController.text.trim(),
        );
        entries.add((
          id: draft.id,
          exerciseId: exerciseId,
          orderIndex: index,
          targetSets: parseIntOrNull(draft.targetSetsController.text),
          targetReps: parseIntOrNull(draft.targetRepsController.text),
        ));
      }

      await widget.database.routinesRepo.saveRoutineExercises(routineId, entries);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit routine' : 'Create routine'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _saving ? null : _saveRoutine,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Routine name',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Push day, Upper body, Legs...',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Routine exercises',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addExerciseDraft,
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(_exerciseDrafts.length, (index) {
                          final draft = _exerciseDrafts[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _RoutineExerciseDraftCard(
                              index: index,
                              total: _exerciseDrafts.length,
                              draft: draft,
                              onMoveUp: () => _moveDraft(index, index - 1),
                              onMoveDown: () => _moveDraft(index, index + 1),
                              onRemove: () => _removeDraft(index),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RoutineExerciseDraftCard extends StatelessWidget {
  const _RoutineExerciseDraftCard({
    required this.index,
    required this.total,
    required this.draft,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final int total;
  final _RoutineExerciseDraft draft;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6D9CD)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFFF1DDCA),
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: draft.nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Exercise name',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.targetSetsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target sets'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: draft.targetRepsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target reps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: index == 0 ? null : onMoveUp,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                onPressed: index == total - 1 ? null : onMoveDown,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutineExerciseDraft {
  _RoutineExerciseDraft({
    required this.id,
    required String name,
    int? targetSets,
    int? targetReps,
  })  : nameController = TextEditingController(text: name),
        targetSetsController = TextEditingController(
          text: targetSets?.toString() ?? '',
        ),
        targetRepsController = TextEditingController(
          text: targetReps?.toString() ?? '',
        );

  factory _RoutineExerciseDraft.empty() {
    return _RoutineExerciseDraft(id: null, name: '');
  }

  factory _RoutineExerciseDraft.fromExisting(
    RoutineExerciseWithExercise item,
  ) {
    return _RoutineExerciseDraft(
      id: item.routineExercise.id,
      name: item.exercise.name,
      targetSets: item.routineExercise.targetSets,
      targetReps: item.routineExercise.targetReps,
    );
  }

  final int? id;
  final TextEditingController nameController;
  final TextEditingController targetSetsController;
  final TextEditingController targetRepsController;

  void clear() {
    nameController.clear();
    targetSetsController.clear();
    targetRepsController.clear();
  }

  void dispose() {
    nameController.dispose();
    targetSetsController.dispose();
    targetRepsController.dispose();
  }
}
