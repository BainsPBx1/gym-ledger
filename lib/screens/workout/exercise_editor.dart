import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';

/// Full-screen editor for one planned exercise: name, rest between sets,
/// and the preset list of sets (target weight x reps each). This is where
/// everything is entered before going to the gym.
Future<void> showExerciseEditor(
  BuildContext context,
  WidgetRef ref,
  int splitId,
  int weekday, {
  PlanExercise? existing,
  int position = 0,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ExerciseEditorScreen(
        splitId: splitId,
        weekday: weekday,
        existing: existing,
        position: position,
      ),
    ),
  );
}

class _SetRow {
  final TextEditingController weight;
  final TextEditingController reps;
  _SetRow(double w, int r)
      : weight = TextEditingController(
            text: w == 0 ? '' : (w == w.roundToDouble() ? '${w.round()}' : '$w')),
        reps = TextEditingController(text: '$r');
  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

class _ExerciseEditorScreen extends ConsumerStatefulWidget {
  final int splitId;
  final int weekday;
  final PlanExercise? existing;
  final int position;
  const _ExerciseEditorScreen({
    required this.splitId,
    required this.weekday,
    this.existing,
    required this.position,
  });

  @override
  ConsumerState<_ExerciseEditorScreen> createState() =>
      _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends ConsumerState<_ExerciseEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _rest;
  final List<_SetRow> _sets = [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _rest =
        TextEditingController(text: '${widget.existing?.restSeconds ?? 90}');
    if (widget.existing != null) {
      _loadSets();
    } else {
      // Sensible starting point: 3 sets of 8, weights blank.
      for (var i = 0; i < 3; i++) {
        _sets.add(_SetRow(0, 8));
      }
    }
  }

  Future<void> _loadSets() async {
    final sets =
        await ref.read(splitDaoProvider).setsFor(widget.existing!.id!);
    setState(() {
      _sets.clear();
      if (sets.isEmpty) {
        for (var i = 0; i < 3; i++) {
          _sets.add(_SetRow(0, 8));
        }
      } else {
        for (final s in sets) {
          _sets.add(_SetRow(s.targetWeightKg, s.targetReps));
        }
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _rest.dispose();
    for (final s in _sets) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _sets.isEmpty) return;
    final dao = ref.read(splitDaoProvider);
    final rest = (int.tryParse(_rest.text.trim()) ?? 90).clamp(5, 3600);

    int exerciseId;
    if (widget.existing == null) {
      exerciseId = await dao.insertExercise(PlanExercise(
        splitId: widget.splitId,
        weekday: widget.weekday,
        name: name,
        position: widget.position,
        restSeconds: rest,
      ));
    } else {
      exerciseId = widget.existing!.id!;
      await dao.updateExercise(PlanExercise(
        id: exerciseId,
        splitId: widget.splitId,
        weekday: widget.weekday,
        name: name,
        position: widget.existing!.position,
        restSeconds: rest,
      ));
    }
    await dao.replaceSets(exerciseId, [
      for (var i = 0; i < _sets.length; i++)
        PlanSet(
          exerciseId: exerciseId,
          setIndex: i,
          targetWeightKg: double.tryParse(
                  _sets[i].weight.text.trim().replaceAll(',', '.')) ??
              0,
          targetReps: int.tryParse(_sets[i].reps.text.trim()) ?? 8,
        ),
    ]);
    ref.read(workoutsVersionProvider.notifier).state++;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'ADD EXERCISE' : 'EDIT EXERCISE'),
      ),
      body: LedgerBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Exercise name (e.g. Bench Press)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rest,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: monoFont),
              decoration: const InputDecoration(
                  labelText: 'Rest between sets (seconds)',
                  helperText: 'e.g. 60–120'),
            ),
            const SizedBox(height: 20),
            const MonoLabel('Planned sets', size: 12),
            const SizedBox(height: 8),
            for (var i = 0; i < _sets.length; i++) ...[
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: MonoLabel('SET ${i + 1}', size: 12, color: c.ink),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _sets[i].weight,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: monoFont),
                      decoration: const InputDecoration(labelText: 'kg'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('×',
                        style: TextStyle(fontSize: 20, color: c.inkFaint)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _sets[i].reps,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: monoFont),
                      decoration: const InputDecoration(labelText: 'reps'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: c.inkFaint),
                    onPressed: _sets.length <= 1
                        ? null
                        : () => setState(() => _sets.removeAt(i).dispose()),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.ink, width: 2),
                  minimumSize: const Size(0, 52)),
              icon: const Icon(Icons.add),
              label: const Text('Add a set'),
              onPressed: () => setState(() {
                // New set starts from the previous set's numbers.
                final last = _sets.lastOrNull;
                _sets.add(_SetRow(
                  double.tryParse(last?.weight.text.trim() ?? '') ?? 0,
                  int.tryParse(last?.reps.text.trim() ?? '') ?? 8,
                ));
              }),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 60,
              child: StampButton(label: 'Save exercise', onPressed: _save),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
