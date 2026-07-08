import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';

/// Collapses meal-level detail older than ~12 months into monthly summaries
/// and deletes the detail rows (plus their photos). Workout history and PRs
/// are never archived — they stay fully detailed indefinitely.
///
/// Runs at app start; it's a no-op when there's nothing old enough.
class ArchivalService {
  ArchivalService(this._db);
  final AppDatabase _db;

  /// Returns the number of meal rows archived.
  Future<int> run({DateTime? now}) async {
    final ts = now ?? DateTime.now();
    // Cutoff: first day of the month 12 months back, so partial months are
    // never archived.
    final cutoff = DateTime(ts.year, ts.month - 12, 1);
    final cutoffMs = cutoff.millisecondsSinceEpoch;

    final photoRows = await _db.db.query('meal_logs',
        columns: ['photo_path'],
        where: 'logged_at < ? AND photo_path IS NOT NULL',
        whereArgs: [cutoffMs]);

    late final int archived;
    await _db.db.transaction((txn) async {
      final months = await txn.rawQuery('''
        SELECT strftime('%Y-%m', logged_at / 1000, 'unixepoch', 'localtime') AS month,
               COUNT(DISTINCT date(logged_at / 1000, 'unixepoch', 'localtime')) AS days_logged,
               SUM(calories) AS cal, SUM(protein_g) AS p, SUM(carbs_g) AS c,
               SUM(fat_g) AS f, COUNT(*) AS meals
        FROM meal_logs WHERE logged_at < ?
        GROUP BY month''', [cutoffMs]);

      for (final m in months) {
        // Merge with any existing summary for the month (idempotent across
        // repeated partial runs).
        final existing = await txn.query('monthly_summaries',
            where: 'month = ?', whereArgs: [m['month']], limit: 1);
        final prev = existing.isEmpty ? null : existing.first;
        await txn.insert(
            'monthly_summaries',
            {
              'month': m['month'],
              'days_logged': (m['days_logged'] as num).toInt() +
                  ((prev?['days_logged'] as num?)?.toInt() ?? 0),
              'total_calories': (m['cal'] as num).toDouble() +
                  ((prev?['total_calories'] as num?)?.toDouble() ?? 0),
              'total_protein_g': (m['p'] as num).toDouble() +
                  ((prev?['total_protein_g'] as num?)?.toDouble() ?? 0),
              'total_carbs_g': (m['c'] as num).toDouble() +
                  ((prev?['total_carbs_g'] as num?)?.toDouble() ?? 0),
              'total_fat_g': (m['f'] as num).toDouble() +
                  ((prev?['total_fat_g'] as num?)?.toDouble() ?? 0),
              'meal_count': (m['meals'] as num).toInt() +
                  ((prev?['meal_count'] as num?)?.toInt() ?? 0),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      archived = await txn
          .delete('meal_logs', where: 'logged_at < ?', whereArgs: [cutoffMs]);
    });

    for (final r in photoRows) {
      final path = r['photo_path'] as String?;
      if (path != null) {
        try {
          await File(path).delete();
        } on FileSystemException {
          // Already gone — fine.
        }
      }
    }
    return archived;
  }
}
