import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../data/daos.dart';
import '../data/db.dart';
import '../data/models.dart';

/// Manual export to a file the user controls. JSON carries everything;
/// CSV is a flat meal + set log dump for spreadsheets. There is no cloud
/// backup by design, so the app nudges (gently) when the last export is old.
class ExportService {
  ExportService(this._db);
  final AppDatabase _db;

  Future<String> buildJson() async {
    final foods = await FoodDao(_db).all();
    final meals = await MealDao(_db).all();
    final workouts = WorkoutDao(_db);
    final sessions = await workouts.sessions();
    final sets = await workouts.allSets();
    final prs = await PrDao(_db).all();
    final windows = await GymWindowDao(_db).all();
    final summaries = await _db.db.query('monthly_summaries');
    final splits = await _db.db.query('splits');
    final planExercises = await _db.db.query('plan_exercises');
    final planSets = await _db.db.query('plan_sets');

    return const JsonEncoder.withIndent('  ').convert({
      'app': 'gym_ledger',
      'exportedAt': DateTime.now().toIso8601String(),
      'foods': foods.map((f) => f.toMap()).toList(),
      'mealLogs': meals.map((m) => m.toMap()).toList(),
      'monthlySummaries': summaries.map(MonthlySummary.fromMap).map((s) => s.toMap()).toList(),
      'splits': splits,
      'planExercises': planExercises,
      'planSets': planSets,
      'workoutSessions': sessions.map((s) => s.toMap()).toList(),
      'setLogs': sets.map((s) => s.toMap()).toList(),
      'prs': prs.map((p) => p.toMap()).toList(),
      'gymWindows': windows.map((w) => w.toMap()).toList(),
    });
  }

  Future<String> buildCsv() async {
    final meals = await MealDao(_db).all();
    final sets = await WorkoutDao(_db).allSets();
    final b = StringBuffer();
    b.writeln('type,date,name,servings,calories,protein_g,carbs_g,fat_g,weight_kg,reps');
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    for (final m in meals) {
      b.writeln('meal,${m.loggedAt.toIso8601String()},${esc(m.name)},'
          '${m.servings},${m.calories},${m.proteinG},${m.carbsG},${m.fatG},,');
    }
    for (final s in sets) {
      b.writeln('set,${s.loggedAt.toIso8601String()},${esc(s.exercise)},'
          ',,,,,${s.weightKg},${s.reps}');
    }
    return b.toString();
  }

  /// Prompts for a save location and writes the export. Returns the path,
  /// or null if the user cancelled.
  Future<String?> exportToFile({required bool asJson}) async {
    final content = asJson ? await buildJson() : await buildCsv();
    final name =
        'gym_ledger_${DateTime.now().toIso8601String().substring(0, 10)}'
        '${asJson ? '.json' : '.csv'}';
    final bytes = Uint8List.fromList(utf8.encode(content));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup',
      fileName: name,
      bytes: bytes,
    );
    if (path == null) return null;
    // On desktop, saveFile returns a path without writing; write it there.
    final f = File(path);
    if (!await f.exists() || (await f.length()) == 0) {
      await f.writeAsBytes(bytes);
    }
    return path;
  }
}
