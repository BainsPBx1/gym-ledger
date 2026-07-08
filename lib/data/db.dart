import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Owns the single app database. Typed access goes through the DAOs in this
/// package; nothing else touches SQL.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static const _version = 3;

  static Future<AppDatabase> open() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'gym_ledger', 'gym_ledger.db');
    await Directory(p.dirname(path)).create(recursive: true);
    return openAt(path);
  }

  /// Test entry point: open at an explicit path (or in memory).
  static Future<AppDatabase> openAt(String path) async {
    final db = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: _version,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: _create,
          onUpgrade: _upgrade,
        ));
    return AppDatabase._(db);
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE,
        tags TEXT NOT NULL DEFAULT '',
        calories REAL NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        serving_desc TEXT NOT NULL DEFAULT '1 serving',
        created_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE meal_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_id INTEGER REFERENCES foods(id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        servings REAL NOT NULL DEFAULT 1,
        calories REAL NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        logged_at INTEGER NOT NULL,
        photo_path TEXT,
        photo_hash TEXT
      )''');
    await db.execute('CREATE INDEX idx_meal_logs_at ON meal_logs(logged_at)');
    await db.execute('''
      CREATE TABLE monthly_summaries (
        month TEXT PRIMARY KEY,
        days_logged INTEGER NOT NULL,
        total_calories REAL NOT NULL,
        total_protein_g REAL NOT NULL,
        total_carbs_g REAL NOT NULL,
        total_fat_g REAL NOT NULL,
        meal_count INTEGER NOT NULL
      )''');
    await _createPlanTables(db);
    await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER,
        template_name TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER
      )''');
    await db.execute(
        'CREATE INDEX idx_sessions_at ON workout_sessions(started_at)');
    await db.execute('''
      CREATE TABLE set_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
        exercise TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        reps INTEGER NOT NULL,
        logged_at INTEGER NOT NULL
      )''');
    await db
        .execute('CREATE INDEX idx_set_logs_ex ON set_logs(exercise, logged_at)');
    // Set logs are append-only by hard product requirement: the monthly
    // graph's integrity depends on logs never being retroactively changed.
    // These triggers enforce it at the database layer, below any code path.
    await db.execute('''
      CREATE TRIGGER set_logs_no_update BEFORE UPDATE ON set_logs
      BEGIN SELECT RAISE(ABORT, 'set logs are locked'); END''');
    await db.execute('''
      CREATE TRIGGER set_logs_no_delete BEFORE DELETE ON set_logs
      BEGIN SELECT RAISE(ABORT, 'set logs are locked'); END''');
    await db.execute('''
      CREATE TABLE prs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        date INTEGER NOT NULL,
        media_path TEXT,
        media_type TEXT
      )''');
    await db.execute('''
      CREATE TABLE gym_windows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        days_mask INTEGER NOT NULL,
        start_minute INTEGER NOT NULL,
        end_minute INTEGER NOT NULL,
        remind_after_minutes INTEGER NOT NULL DEFAULT 30,
        enabled INTEGER NOT NULL DEFAULT 1
      )''');
  }

  /// The workout plan: splits (e.g. PPL, Bro split) contain per-weekday
  /// exercises, and each exercise carries its preset sets — target weight and
  /// reps per set — plus the rest period between sets. All preset by the
  /// user before the gym; only actual weight/reps get edited mid-workout.
  static Future<void> _createPlanTables(Database db) async {
    await db.execute('''
      CREATE TABLE splits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE plan_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        split_id INTEGER NOT NULL REFERENCES splits(id) ON DELETE CASCADE,
        weekday INTEGER NOT NULL, -- 1 = Monday ... 7 = Sunday
        name TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        rest_seconds INTEGER NOT NULL DEFAULT 90
      )''');
    await db.execute(
        'CREATE INDEX idx_plan_ex ON plan_exercises(split_id, weekday, position)');
    await db.execute('''
      CREATE TABLE plan_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id INTEGER NOT NULL REFERENCES plan_exercises(id) ON DELETE CASCADE,
        set_index INTEGER NOT NULL,
        target_weight_kg REAL NOT NULL DEFAULT 0,
        target_reps INTEGER NOT NULL DEFAULT 8
      )''');
    await db.execute(
        'CREATE INDEX idx_plan_sets ON plan_sets(exercise_id, set_index)');
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      // v2: template-based workouts became split/weekday plans with per-set
      // targets. Locked set logs and sessions are untouched — history is
      // never rewritten.
      await _createPlanTables(db);
    }
    if (from < 3) {
      // v1's workout_sessions declares a foreign key on workout_templates,
      // and an earlier v2 migration dropped that table — breaking every
      // session insert on upgraded devices. The table must keep existing
      // (empty, unused) so the old FK clause still resolves; new rows write
      // template_id NULL.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS workout_templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          position INTEGER NOT NULL DEFAULT 0
        )''');
    }
  }

  Future<void> close() => db.close();
}
