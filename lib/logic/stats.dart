import '../data/db.dart';
import '../data/models.dart';

/// Relational aggregates that power the monthly graph and streak counters.
class StatsDao {
  StatsDao(this._db);
  final AppDatabase _db;

  /// One aggregate per day of [month] (1st..today for the current month,
  /// whole month otherwise). Days with no meal log at all are `missed` —
  /// they render as negative bars on the graph — distinct from days that
  /// were logged but landed under target.
  Future<List<DayAggregate>> daysForMonth(
      DateTime month, Targets targets) async {
    final first = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var end = nextMonth;
    if (!nextMonth.isBefore(today.add(const Duration(days: 1)))) {
      end = today.add(const Duration(days: 1));
      if (end.isBefore(first)) return const [];
    }

    final mealRows = await _db.db.rawQuery('''
      SELECT date(logged_at / 1000, 'unixepoch', 'localtime') AS day,
             SUM(calories) AS cal, SUM(protein_g) AS p,
             SUM(carbs_g) AS c, SUM(fat_g) AS f
      FROM meal_logs
      WHERE logged_at >= ? AND logged_at < ?
      GROUP BY day''',
        [first.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
    final meals = {for (final r in mealRows) r['day'] as String: r};

    final workoutRows = await _db.db.rawQuery('''
      SELECT DISTINCT date(started_at / 1000, 'unixepoch', 'localtime') AS day
      FROM workout_sessions
      WHERE started_at >= ? AND started_at < ?''',
        [first.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
    final workoutDays = {for (final r in workoutRows) r['day'] as String};

    final out = <DayAggregate>[];
    for (var d = first; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final key = _dayKey(d);
      final m = meals[key];
      final workedOut = workoutDays.contains(key);
      if (m == null) {
        out.add(DayAggregate(
          day: d,
          status: DayStatus.missed,
          calories: 0,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          workedOut: workedOut,
        ));
        continue;
      }
      final cal = (m['cal'] as num).toDouble();
      // "On target" = within +/-10% of the calorie target and at least 80%
      // of the protein target; anything logged but outside that band is
      // under/off target.
      final calOk = cal >= targets.calories * 0.9 && cal <= targets.calories * 1.1;
      final proteinOk = (m['p'] as num).toDouble() >= targets.proteinG * 0.8;
      out.add(DayAggregate(
        day: d,
        status: calOk && proteinOk
            ? DayStatus.onTarget
            : DayStatus.loggedUnderTarget,
        calories: cal,
        proteinG: (m['p'] as num).toDouble(),
        carbsG: (m['c'] as num).toDouble(),
        fatG: (m['f'] as num).toDouble(),
        workedOut: workedOut,
      ));
    }
    return out;
  }

  /// Consecutive days logged, counting back from today (today counts once
  /// anything is logged; an unlogged today doesn't break yesterday's streak).
  Future<int> loggingStreak() async {
    final rows = await _db.db.rawQuery('''
      SELECT DISTINCT date(logged_at / 1000, 'unixepoch', 'localtime') AS day
      FROM meal_logs ORDER BY day DESC LIMIT 400''');
    final days = rows.map((r) => r['day'] as String).toSet();
    final now = DateTime.now();
    var streak = 0;
    var d = DateTime(now.year, now.month, now.day);
    if (!days.contains(_dayKey(d))) {
      d = d.subtract(const Duration(days: 1)); // today not logged yet is ok
    }
    while (days.contains(_dayKey(d))) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Number of days with at least one workout session in [month].
  Future<int> workoutDaysInMonth(DateTime month) async {
    final first = DateTime(month.year, month.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    final rows = await _db.db.rawQuery('''
      SELECT COUNT(DISTINCT date(started_at / 1000, 'unixepoch', 'localtime')) AS n
      FROM workout_sessions WHERE started_at >= ? AND started_at < ?''',
        [first.millisecondsSinceEpoch, next.millisecondsSinceEpoch]);
    return (rows.first['n'] as num).toInt();
  }

  /// True if any workout session started today — used by the reminder
  /// scheduler to decide whether the gym-window notification should fire.
  Future<bool> workedOutToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final rows = await _db.db.rawQuery(
        'SELECT COUNT(*) AS n FROM workout_sessions WHERE started_at >= ?',
        [start.millisecondsSinceEpoch]);
    return (rows.first['n'] as num) > 0;
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
