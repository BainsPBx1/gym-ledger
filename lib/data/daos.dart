import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'models.dart';

class SettingsDao {
  SettingsDao(this._db);
  final AppDatabase _db;

  Future<AppSettings> load() async {
    final rows = await _db.db.query('settings');
    if (rows.isEmpty) return AppSettings.defaults;
    final map = {for (final r in rows) r['key'] as String: r['value'] as String};
    final j = map['app'] == null ? null : jsonDecode(map['app']!) as Map;
    if (j == null) return AppSettings.defaults;
    return AppSettings(
      onboarded: j['onboarded'] as bool? ?? false,
      goal: Goal.values.byName(j['goal'] as String? ?? 'maintain'),
      activity:
          ActivityLevel.values.byName(j['activity'] as String? ?? 'moderate'),
      weightKg: (j['weightKg'] as num?)?.toDouble() ?? 75,
      targets: Targets(
        calories: j['calories'] as int? ?? 2600,
        proteinG: j['proteinG'] as int? ?? 135,
        carbsG: j['carbsG'] as int? ?? 293,
        fatG: j['fatG'] as int? ?? 72,
      ),
      themeMode: j['themeMode'] as String? ?? 'system',
      biometricLock: j['biometricLock'] as bool? ?? false,
      lastExportAt: j['lastExportAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(j['lastExportAt'] as int),
    );
  }

  Future<void> save(AppSettings s) async {
    final value = jsonEncode({
      'onboarded': s.onboarded,
      'goal': s.goal.name,
      'activity': s.activity.name,
      'weightKg': s.weightKg,
      'calories': s.targets.calories,
      'proteinG': s.targets.proteinG,
      'carbsG': s.targets.carbsG,
      'fatG': s.targets.fatG,
      'themeMode': s.themeMode,
      'biometricLock': s.biometricLock,
      'lastExportAt': s.lastExportAt?.millisecondsSinceEpoch,
    });
    await _db.db.insert('settings', {'key': 'app', 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class FoodDao {
  FoodDao(this._db);
  final AppDatabase _db;

  Future<int> insert(Food f) => _db.db.insert('foods', f.toMap()..remove('id'));

  Future<void> update(Food f) =>
      _db.db.update('foods', f.toMap()..remove('id'),
          where: 'id = ?', whereArgs: [f.id]);

  Future<void> delete(int id) =>
      _db.db.delete('foods', where: 'id = ?', whereArgs: [id]);

  Future<Food?> byBarcode(String barcode) async {
    final rows = await _db.db
        .query('foods', where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    return rows.isEmpty ? null : Food.fromMap(rows.first);
  }

  Future<Food?> byId(int id) async {
    final rows =
        await _db.db.query('foods', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Food.fromMap(rows.first);
  }

  Future<List<Food>> search(String query) async {
    final rows = await _db.db.query('foods',
        where: 'name LIKE ? OR tags LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name COLLATE NOCASE');
    return rows.map(Food.fromMap).toList();
  }

  Future<List<Food>> all() async {
    final rows = await _db.db.query('foods', orderBy: 'name COLLATE NOCASE');
    return rows.map(Food.fromMap).toList();
  }
}

class MealDao {
  MealDao(this._db);
  final AppDatabase _db;

  Future<int> insert(MealLog log) =>
      _db.db.insert('meal_logs', log.toMap()..remove('id'));

  Future<void> delete(int id) =>
      _db.db.delete('meal_logs', where: 'id = ?', whereArgs: [id]);

  Future<List<MealLog>> forDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _db.db.query('meal_logs',
        where: 'logged_at >= ? AND logged_at < ?',
        whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
        orderBy: 'logged_at');
    return rows.map(MealLog.fromMap).toList();
  }

  /// All logs that carry a photo hash, newest first — candidate set for
  /// meal photo matching.
  Future<List<MealLog>> withPhotoHashes({int limit = 500}) async {
    final rows = await _db.db.query('meal_logs',
        where: 'photo_hash IS NOT NULL',
        orderBy: 'logged_at DESC',
        limit: limit);
    return rows.map(MealLog.fromMap).toList();
  }

  Future<List<MealLog>> all() async {
    final rows = await _db.db.query('meal_logs', orderBy: 'logged_at');
    return rows.map(MealLog.fromMap).toList();
  }
}

/// The preset workout plan: splits, their per-weekday exercises, and each
/// exercise's target sets.
class SplitDao {
  SplitDao(this._db);
  final AppDatabase _db;

  Future<int> insertSplit(Split s) =>
      _db.db.insert('splits', s.toMap()..remove('id'));

  Future<void> renameSplit(int id, String name) =>
      _db.db.update('splits', {'name': name}, where: 'id = ?', whereArgs: [id]);

  Future<void> deleteSplit(int id) =>
      _db.db.delete('splits', where: 'id = ?', whereArgs: [id]);

  Future<List<Split>> splits() async {
    final rows = await _db.db.query('splits', orderBy: 'position, id');
    return rows.map(Split.fromMap).toList();
  }

  Future<int> insertExercise(PlanExercise e) =>
      _db.db.insert('plan_exercises', e.toMap()..remove('id'));

  Future<void> updateExercise(PlanExercise e) => _db.db.update(
      'plan_exercises', e.toMap()..remove('id'),
      where: 'id = ?', whereArgs: [e.id]);

  Future<void> deleteExercise(int id) =>
      _db.db.delete('plan_exercises', where: 'id = ?', whereArgs: [id]);

  Future<List<PlanExercise>> exercisesFor(int splitId, int weekday) async {
    final rows = await _db.db.query('plan_exercises',
        where: 'split_id = ? AND weekday = ?',
        whereArgs: [splitId, weekday],
        orderBy: 'position, id');
    return rows.map(PlanExercise.fromMap).toList();
  }

  /// Weekdays of a split that have at least one exercise planned.
  Future<Set<int>> plannedWeekdays(int splitId) async {
    final rows = await _db.db.rawQuery(
        'SELECT DISTINCT weekday FROM plan_exercises WHERE split_id = ?',
        [splitId]);
    return rows.map((r) => r['weekday'] as int).toSet();
  }

  Future<List<PlanSet>> setsFor(int exerciseId) async {
    final rows = await _db.db.query('plan_sets',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
        orderBy: 'set_index');
    return rows.map(PlanSet.fromMap).toList();
  }

  /// Replaces an exercise's preset sets wholesale (editor semantics).
  Future<void> replaceSets(int exerciseId, List<PlanSet> sets) async {
    await _db.db.transaction((txn) async {
      await txn.delete('plan_sets',
          where: 'exercise_id = ?', whereArgs: [exerciseId]);
      for (var i = 0; i < sets.length; i++) {
        await txn.insert('plan_sets', {
          'exercise_id': exerciseId,
          'set_index': i,
          'target_weight_kg': sets[i].targetWeightKg,
          'target_reps': sets[i].targetReps,
        });
      }
    });
  }
}

class WorkoutDao {
  WorkoutDao(this._db);
  final AppDatabase _db;

  // Sessions ----------------------------------------------------------------

  Future<int> startSession(WorkoutSession s) =>
      _db.db.insert('workout_sessions', s.toMap()..remove('id'));

  Future<void> endSession(int id, DateTime endedAt) => _db.db.update(
      'workout_sessions', {'ended_at': endedAt.millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);

  Future<WorkoutSession?> activeSession() async {
    final rows = await _db.db.query('workout_sessions',
        where: 'ended_at IS NULL', orderBy: 'started_at DESC', limit: 1);
    return rows.isEmpty ? null : WorkoutSession.fromMap(rows.first);
  }

  Future<List<WorkoutSession>> sessions() async {
    final rows =
        await _db.db.query('workout_sessions', orderBy: 'started_at DESC');
    return rows.map(WorkoutSession.fromMap).toList();
  }

  // Sets: insert-only. There is deliberately no update or delete here, and
  // DB triggers reject them anyway — saved sets are locked, permanently.

  Future<int> logSet(SetLog s) =>
      _db.db.insert('set_logs', s.toMap()..remove('id'));

  Future<List<SetLog>> setsForSession(int sessionId) async {
    final rows = await _db.db.query('set_logs',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'logged_at');
    return rows.map(SetLog.fromMap).toList();
  }

  /// The most recent logged weight for an exercise, used to pre-fill input.
  Future<SetLog?> lastSetFor(String exercise) async {
    final rows = await _db.db.query('set_logs',
        where: 'exercise = ?',
        whereArgs: [exercise],
        orderBy: 'logged_at DESC',
        limit: 1);
    return rows.isEmpty ? null : SetLog.fromMap(rows.first);
  }

  Future<List<SetLog>> allSets() async {
    final rows = await _db.db.query('set_logs', orderBy: 'logged_at');
    return rows.map(SetLog.fromMap).toList();
  }
}

class PrDao {
  PrDao(this._db);
  final AppDatabase _db;

  Future<int> insert(PrEntry e) => _db.db.insert('prs', e.toMap()..remove('id'));

  Future<void> delete(int id) =>
      _db.db.delete('prs', where: 'id = ?', whereArgs: [id]);

  /// Scoreboard order: most recent first.
  Future<List<PrEntry>> all() async {
    final rows = await _db.db.query('prs', orderBy: 'date DESC, weight_kg DESC');
    return rows.map(PrEntry.fromMap).toList();
  }

  /// Best (heaviest) PR per exercise, for "is this a new best?" checks.
  Future<double?> bestFor(String exercise) async {
    final rows = await _db.db.rawQuery(
        'SELECT MAX(weight_kg) AS best FROM prs WHERE exercise = ?',
        [exercise]);
    final v = rows.first['best'];
    return v == null ? null : (v as num).toDouble();
  }
}

class GymWindowDao {
  GymWindowDao(this._db);
  final AppDatabase _db;

  Future<int> insert(GymWindow w) =>
      _db.db.insert('gym_windows', w.toMap()..remove('id'));

  Future<void> update(GymWindow w) => _db.db.update(
      'gym_windows', w.toMap()..remove('id'),
      where: 'id = ?', whereArgs: [w.id]);

  Future<void> delete(int id) =>
      _db.db.delete('gym_windows', where: 'id = ?', whereArgs: [id]);

  Future<List<GymWindow>> all() async {
    final rows = await _db.db.query('gym_windows', orderBy: 'start_minute');
    return rows.map(GymWindow.fromMap).toList();
  }
}
