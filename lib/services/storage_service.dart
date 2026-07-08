import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db.dart';

class StorageBreakdown {
  final int mealsBytes; // meal rows' share of the database file
  final int workoutsBytes; // workout/PR rows' share of the database file
  final int mealPhotosBytes;
  final int prMediaBytes;
  final int totalBytes;
  const StorageBreakdown({
    required this.mealsBytes,
    required this.workoutsBytes,
    required this.mealPhotosBytes,
    required this.prMediaBytes,
    required this.totalBytes,
  });
}

/// Sizes for the storage breakdown screen. Database size is apportioned
/// between meals and workouts by row count — approximate, clearly labeled
/// as such in the UI.
class StorageService {
  StorageService(this._db);
  final AppDatabase _db;

  Future<StorageBreakdown> breakdown() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = p.join(docs.path, 'gym_ledger');

    Future<int> dirSize(String path) async {
      final dir = Directory(path);
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final f in dir.list(recursive: true)) {
        if (f is File) total += await f.length();
      }
      return total;
    }

    final dbFile = File(p.join(root, 'gym_ledger.db'));
    final dbBytes = await dbFile.exists() ? await dbFile.length() : 0;

    Future<int> count(String sql) async =>
        ((await _db.db.rawQuery(sql)).first.values.first as num?)?.toInt() ?? 0;
    final mealRows = await count('SELECT COUNT(*) FROM meal_logs') +
        await count('SELECT COUNT(*) FROM foods') +
        await count('SELECT COUNT(*) FROM monthly_summaries');
    final workoutRows = await count('SELECT COUNT(*) FROM set_logs') +
        await count('SELECT COUNT(*) FROM workout_sessions') +
        await count('SELECT COUNT(*) FROM prs');
    final totalRows = mealRows + workoutRows;

    final mealsShare =
        totalRows == 0 ? dbBytes ~/ 2 : dbBytes * mealRows ~/ totalRows;
    final mealPhotos = await dirSize(p.join(root, 'meals'));
    final prMedia = await dirSize(p.join(root, 'prs'));

    return StorageBreakdown(
      mealsBytes: mealsShare,
      workoutsBytes: dbBytes - mealsShare,
      mealPhotosBytes: mealPhotos,
      prMediaBytes: prMedia,
      totalBytes: dbBytes + mealPhotos + prMedia,
    );
  }
}
