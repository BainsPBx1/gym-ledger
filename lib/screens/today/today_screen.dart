import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'log_meal_sheet.dart';

/// The daily view: calories and macros against target, today's ledger of
/// meals, and the logging streak as tally marks.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final logs = ref.watch(dayLogsProvider(day));
    final streak = ref.watch(loggingStreakProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final targets = settings?.targets ??
        const Targets(calories: 2600, proteinG: 135, carbsG: 293, fatG: 72);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEE d MMM').format(now).toUpperCase()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TallyMarks(count: streak.valueOrNull ?? 0, height: 20),
                const MonoLabel('day streak', size: 9),
              ],
            ),
          ),
        ],
      ),
      body: LedgerBackground(
        child: logs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (meals) {
            final cal = meals.fold(0.0, (s, m) => s + m.calories);
            final p = meals.fold(0.0, (s, m) => s + m.proteinG);
            final cb = meals.fold(0.0, (s, m) => s + m.carbsG);
            final f = meals.fold(0.0, (s, m) => s + m.fatG);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                LedgerCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const MonoLabel('Calories'),
                              PixelNumber('${cal.round()}', size: 62),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MonoLabel('of ${targets.calories}'),
                              PixelNumber(
                                '${(targets.calories - cal).round()}',
                                size: 34,
                                color: cal > targets.calories
                                    ? c.negative
                                    : c.secondary,
                              ),
                              const MonoLabel('left', size: 9),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _bar(context, cal / targets.calories, c.accent),
                      const Divider(height: 28),
                      _macroRow(context, 'PROTEIN', p, targets.proteinG),
                      const SizedBox(height: 10),
                      _macroRow(context, 'CARBS', cb, targets.carbsG),
                      const SizedBox(height: 10),
                      _macroRow(context, 'FAT', f, targets.fatG),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const MonoLabel("Today's entries", size: 13),
                const SizedBox(height: 8),
                if (meals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                        child: MonoLabel('Nothing in the ledger yet',
                            size: 13, color: c.inkFaint)),
                  ),
                for (final m in meals) ...[
                  _MealRow(meal: m),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          height: 60, // FAB gets loose full-body constraints; must be bounded
          child: StampButton(
            label: '+ Log a meal',
            onPressed: () => showLogMealSheet(context, ref),
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, double frac, Color color) {
    final c = context.ledger;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: frac.clamp(0.0, 1.0),
        minHeight: 10,
        backgroundColor: c.rule,
        color: frac > 1.1 ? c.negative : color,
      ),
    );
  }

  Widget _macroRow(
      BuildContext context, String label, double value, int target) {
    final c = context.ledger;
    return Row(
      children: [
        SizedBox(width: 72, child: MonoLabel(label, size: 11)),
        Expanded(
            child:
                _bar(context, target == 0 ? 0 : value / target, c.secondary)),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            '${value.round()}/${target}g',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontFamily: monoFont, fontSize: 13, color: c.inkFaint),
          ),
        ),
      ],
    );
  }
}

class _MealRow extends ConsumerWidget {
  final MealLog meal;
  const _MealRow({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                MonoLabel(
                  '${DateFormat.Hm().format(meal.loggedAt)}'
                  '${meal.servings != 1 ? ' · ${_trim(meal.servings)}x' : ''}'
                  ' · P${meal.proteinG.round()} C${meal.carbsG.round()} F${meal.fatG.round()}',
                  size: 11,
                ),
              ],
            ),
          ),
          Text('${meal.calories.round()}',
              style: TextStyle(
                  fontFamily: monoFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.ink)),
          const MonoLabel(' kcal', size: 10),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: c.inkFaint),
            tooltip: 'Remove entry',
            onPressed: () async {
              await ref.read(mealDaoProvider).delete(meal.id!);
              ref.read(mealsVersionProvider.notifier).state++;
            },
          ),
        ],
      ),
    );
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toString();
}
