import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';
import 'exercise_editor.dart';
import 'guided_session_screen.dart';

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

/// The workout planner. The user builds splits (PPL, Bro split, ...), plans
/// exercises per weekday — each with preset sets of target weight x reps and
/// a rest period — then at the gym just presses PLAY and follows along.
class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    final splitsAsync = ref.watch(splitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('LIFT')),
      body: LedgerBackground(
        child: splitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (splits) {
            if (splits.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center, size: 64, color: c.inkFaint),
                      const SizedBox(height: 16),
                      const MonoLabel(
                          'Build your split — PPL, Bro split, whatever works',
                          size: 12),
                      const SizedBox(height: 24),
                      StampButton(
                        label: 'New split',
                        onPressed: () => _newSplit(context, ref),
                      ),
                    ],
                  ),
                ),
              );
            }

            final selectedId = ref.watch(selectedSplitProvider);
            final split =
                splits.where((s) => s.id == selectedId).firstOrNull ??
                    splits.first;
            final weekday = ref.watch(selectedWeekdayProvider);
            final planned =
                ref.watch(plannedWeekdaysProvider(split.id!)).valueOrNull ??
                    const <int>{};

            return Column(
              children: [
                // Split switcher — one tap.
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final s in splits)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: ChoiceChip(
                            label: Text(s.name.toUpperCase(),
                                style: const TextStyle(
                                    fontFamily: monoFont,
                                    fontWeight: FontWeight.w700)),
                            selected: s.id == split.id,
                            selectedColor: c.accent.withValues(alpha: 0.22),
                            side: BorderSide(
                                color: s.id == split.id ? c.accent : c.ink,
                                width: 2),
                            onSelected: (_) => ref
                                .read(selectedSplitProvider.notifier)
                                .state = s.id,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: ActionChip(
                          label: const Text('+ NEW',
                              style: TextStyle(fontFamily: monoFont)),
                          side: BorderSide(color: c.inkFaint, width: 2),
                          onPressed: () => _newSplit(context, ref),
                        ),
                      ),
                    ],
                  ),
                ),
                // Weekday chips Mon..Sun; dot under days with a plan.
                SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      for (var d = 1; d <= 7; d++)
                        Expanded(
                          child: InkWell(
                            onTap: () => ref
                                .read(selectedWeekdayProvider.notifier)
                                .state = d,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 5),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: d == weekday
                                            ? c.accent
                                            : Colors.transparent,
                                        width: 2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    weekdayNames[d - 1].toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: monoFont,
                                      fontSize: 12,
                                      fontWeight: d == weekday
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: d == weekday ? c.accent : c.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: planned.contains(d)
                                        ? c.secondary
                                        : Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: _DayPlan(split: split, weekday: weekday)),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> _newSplit(BuildContext context, WidgetRef ref) async {
  final ctrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dCtx) => AlertDialog(
      backgroundColor: dCtx.ledger.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: dCtx.ledger.ink, width: 2),
      ),
      title: const Text('New split'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration:
            const InputDecoration(labelText: 'Name (e.g. PPL, Bro split)'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
            child: const Text('Create')),
      ],
    ),
  );
  if (name == null || name.isEmpty) return;
  final id = await ref.read(splitDaoProvider).insertSplit(Split(name: name));
  ref.read(selectedSplitProvider.notifier).state = id;
  ref.read(workoutsVersionProvider.notifier).state++;
}

Future<void> _showSplitMenu(
    BuildContext context, WidgetRef ref, Split split) async {
  final action = await showDialog<String>(
    context: context,
    builder: (dCtx) => SimpleDialog(
      backgroundColor: dCtx.ledger.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: dCtx.ledger.ink, width: 2),
      ),
      title: Text(split.name),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dCtx, 'rename'),
          child: const Text('Rename'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dCtx, 'delete'),
          child: Text('Delete split',
              style: TextStyle(color: dCtx.ledger.negative)),
        ),
      ],
    ),
  );
  if (action == 'rename' && context.mounted) {
    final ctrl = TextEditingController(text: split.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: dCtx.ledger.card,
        title: const Text('Rename split'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(splitDaoProvider).renameSplit(split.id!, name);
      ref.read(workoutsVersionProvider.notifier).state++;
    }
  } else if (action == 'delete' && context.mounted) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Delete ${split.name}?'),
        content:
            const Text('The plan goes; your logged workout history stays.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(splitDaoProvider).deleteSplit(split.id!);
      ref.read(selectedSplitProvider.notifier).state = null;
      ref.read(workoutsVersionProvider.notifier).state++;
    }
  }
}

class _DayPlan extends ConsumerWidget {
  final Split split;
  final int weekday;
  const _DayPlan({required this.split, required this.weekday});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    final exercisesAsync =
        ref.watch(planExercisesProvider((split.id!, weekday)));
    return exercisesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (exercises) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MonoLabel('${split.name} · ${weekdayFull[weekday - 1]}',
                        size: 11),
                    TextButton(
                      onPressed: () => _showSplitMenu(context, ref, split),
                      child: const Text('Split…'),
                    ),
                  ],
                ),
                if (exercises.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: MonoLabel(
                          'Rest day — nothing planned for ${weekdayFull[weekday - 1]}',
                          size: 12,
                          color: c.inkFaint),
                    ),
                  ),
                for (final e in exercises) ...[
                  _ExercisePlanCard(exercise: e),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  height: 56,
                  child: StampButton(
                    label: '+ Add exercise',
                    primary: false,
                    rotation: 0.008,
                    onPressed: () => showExerciseEditor(
                        context, ref, split.id!, weekday,
                        position: exercises.length),
                  ),
                ),
              ],
            ),
          ),
          if (exercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: StampButton(
                  label: '▶ Start workout',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuidedSessionScreen(
                        split: split,
                        weekday: weekday,
                        exercises: exercises,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExercisePlanCard extends ConsumerWidget {
  final PlanExercise exercise;
  const _ExercisePlanCard({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    final sets = ref.watch(planSetsProvider(exercise.id!)).valueOrNull ??
        const <PlanSet>[];
    String trim(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
    final plan = sets
        .map((s) => '${trim(s.targetWeightKg)}kg×${s.targetReps}')
        .join('  ');
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => showExerciseEditor(
          context, ref, exercise.splitId, exercise.weekday,
          existing: exercise),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                MonoLabel('${sets.length} sets · rest ${exercise.restSeconds}s',
                    size: 10),
                if (plan.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(plan,
                      style: TextStyle(
                          fontFamily: monoFont,
                          fontSize: 13,
                          color: c.secondary)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: c.inkFaint),
            tooltip: 'Remove exercise',
            onPressed: () async {
              await ref.read(splitDaoProvider).deleteExercise(exercise.id!);
              ref.read(workoutsVersionProvider.notifier).state++;
            },
          ),
        ],
      ),
    );
  }
}
