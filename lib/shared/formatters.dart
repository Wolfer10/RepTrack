import 'package:rep_track/app_database.dart';

int? parseIntOrNull(String input) {
  return int.tryParse(input.trim());
}

String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatTimeOfDay(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatWeight(double weight) {
  return '${formatWeightNumber(weight)} kg';
}

String formatWeightNumber(double weight) {
  if (weight.truncateToDouble() == weight) {
    return weight.toStringAsFixed(0);
  }
  return weight.toStringAsFixed(1);
}

String buildSetSummary(List<WorkoutSet> sets) {
  return sets
      .map(
        (set) => 'S${set.setNumber}: ${set.reps} reps @ ${formatWeight(set.weight)}',
      )
      .join('  |  ');
}
