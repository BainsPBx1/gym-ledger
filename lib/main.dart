import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db.dart';
import 'logic/archival.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  // Meal detail older than ~12 months collapses into monthly summaries.
  await ArchivalService(db).run();
  runApp(ProviderScope(
    overrides: [dbProvider.overrideWithValue(db)],
    child: const GymLedgerApp(),
  ));
}
