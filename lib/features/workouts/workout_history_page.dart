import 'package:flutter/material.dart';
import 'package:rep_track/app_database.dart';
import 'package:rep_track/shared/formatters.dart';

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  bool _loading = true;
  String? _error;
  List<WorkoutHistoryEntry> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final history = await widget.database.workoutsRepo.getCompletedWorkoutHistory();
      if (!mounted) {
        return;
      }
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutDays = _history
        .map((entry) => DateTime(
              entry.workout.startedAt.year,
              entry.workout.startedAt.month,
              entry.workout.startedAt.day,
            ))
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Workout history')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF1E1D2),
              Color(0xFFF7F0E8),
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!),
                    ))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      children: [
                        _RecentWeekRow(workoutDays: workoutDays),
                        const SizedBox(height: 16),
                        _MonthCalendarCard(workoutDays: workoutDays),
                        const SizedBox(height: 16),
                        _HistorySummaryCard(history: _history),
                        const SizedBox(height: 16),
                        if (_history.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No completed workouts yet.'),
                            ),
                          )
                        else
                          ..._history.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _WorkoutHistoryCard(entry: entry),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _RecentWeekRow extends StatelessWidget {
  const _RecentWeekRow({required this.workoutDays});

  final Set<DateTime> workoutDays;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (index) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - index));
      return date;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 7 days',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: days.map((day) {
                final done = workoutDays.contains(day);
                final isToday = _sameDay(day, today);
                return Expanded(
                  child: Column(
                    children: [
                      Text(_weekdayLabel(day)),
                      const SizedBox(height: 8),
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: done
                              ? const Color(0xFF355D4D)
                              : isToday
                                  ? const Color(0xFFF4D2B0)
                                  : const Color(0xFFE9DED5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: done ? Colors.white : const Color(0xFF22160F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCalendarCard extends StatelessWidget {
  const _MonthCalendarCard({required this.workoutDays});

  final Set<DateTime> workoutDays;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leadingEmpty = firstOfMonth.weekday - 1;

    final cells = <Widget>[];
    for (var i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(now.year, now.month, day);
      final done = workoutDays.contains(date);
      final isToday = _sameDay(date, now);
      cells.add(
        Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: done
                ? const Color(0xFFB74D1F)
                : isToday
                    ? const Color(0xFFF4DCC8)
                    : const Color(0xFFFFFBF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done ? const Color(0xFFB74D1F) : const Color(0xFFE7D7C9),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              color: done ? Colors.white : const Color(0xFF22160F),
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_monthLabel(now.month)} ${now.year}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _WeekdayHeader(label: 'Mon'),
                _WeekdayHeader(label: 'Tue'),
                _WeekdayHeader(label: 'Wed'),
                _WeekdayHeader(label: 'Thu'),
                _WeekdayHeader(label: 'Fri'),
                _WeekdayHeader(label: 'Sat'),
                _WeekdayHeader(label: 'Sun'),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              children: cells,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6F5A4D),
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _HistorySummaryCard extends StatelessWidget {
  const _HistorySummaryCard({required this.history});

  final List<WorkoutHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final totalWorkouts = history.length;
    final totalSets = history.fold<int>(0, (sum, item) => sum + item.setCount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                label: 'Completed workouts',
                value: '$totalWorkouts',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryMetric(
                label: 'Logged sets',
                value: '$totalSets',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

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
          Text(label),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutHistoryCard extends StatelessWidget {
  const _WorkoutHistoryCard({required this.entry});

  final WorkoutHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final duration = entry.workout.endedAt?.difference(entry.workout.startedAt);

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
                    entry.routine.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(formatTimeOfDay(entry.workout.startedAt)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.workout.startedAt.year}-${entry.workout.startedAt.month.toString().padLeft(2, '0')}-${entry.workout.startedAt.day.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${entry.exerciseCount} exercises')),
                Chip(label: Text('${entry.setCount} sets')),
                if (duration != null)
                  Chip(label: Text('Duration ${formatDuration(duration)}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _monthLabel(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}

String _weekdayLabel(DateTime date) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[date.weekday - 1];
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
