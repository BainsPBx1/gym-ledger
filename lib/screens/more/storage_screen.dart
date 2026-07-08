import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage_service.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';

/// Storage breakdown — built in from the start because there's no cloud to
/// quietly absorb growth. Also explains the auto-archival policy.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    return Scaffold(
      appBar: AppBar(title: const Text('STORAGE')),
      body: LedgerBackground(
        child: FutureBuilder<StorageBreakdown>(
          future: ref.read(storageServiceProvider).breakdown(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final b = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      PixelNumber(_fmt(b.totalBytes), size: 56),
                      const MonoLabel('total on this phone', size: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _row(context, 'Meals & food library', b.mealsBytes),
                _row(context, 'Workouts & PRs', b.workoutsBytes),
                _row(context, 'Meal photos', b.mealPhotosBytes),
                _row(context, 'PR photos & videos', b.prMediaBytes),
                const SizedBox(height: 8),
                MonoLabel('Database split is approximate (by row count)',
                    size: 9, color: c.inkFaint),
                const SizedBox(height: 20),
                LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_delete_outlined,
                            size: 20, color: c.secondary),
                        const SizedBox(width: 8),
                        const MonoLabel('Auto-archival', size: 11),
                      ]),
                      const SizedBox(height: 8),
                      const Text(
                        'Meal-by-meal detail older than 12 months is rolled '
                        'up into monthly summaries automatically (photos '
                        'included). Workout history and PRs are never '
                        'archived — they stay fully detailed forever.',
                        style: TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, int bytes) {
    final c = context.ledger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(_fmt(bytes),
              style: TextStyle(
                  fontFamily: monoFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.ink)),
        ],
      ),
    );
  }

  static String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
