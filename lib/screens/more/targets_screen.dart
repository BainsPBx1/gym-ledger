import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../logic/targets.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';

/// Adjust targets by hand, or re-run the onboarding calculation with a new
/// weight/goal/activity.
class TargetsScreen extends ConsumerStatefulWidget {
  const TargetsScreen({super.key});

  @override
  ConsumerState<TargetsScreen> createState() => _TargetsScreenState();
}

class _TargetsScreenState extends ConsumerState<TargetsScreen> {
  late TextEditingController _cal, _p, _c, _f, _weight;
  Goal? _goal;
  ActivityLevel? _activity;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _cal = TextEditingController();
    _p = TextEditingController();
    _c = TextEditingController();
    _f = TextEditingController();
    _weight = TextEditingController();
  }

  void _fill(AppSettings s) {
    if (_loaded) return;
    _loaded = true;
    _cal.text = '${s.targets.calories}';
    _p.text = '${s.targets.proteinG}';
    _c.text = '${s.targets.carbsG}';
    _f.text = '${s.targets.fatG}';
    _weight.text = s.weightKg == s.weightKg.roundToDouble()
        ? '${s.weightKg.round()}'
        : '${s.weightKg}';
    _goal = s.goal;
    _activity = s.activity;
  }

  @override
  void dispose() {
    for (final t in [_cal, _p, _c, _f, _weight]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AppSettings s) async {
    int parse(TextEditingController t, int fallback) =>
        int.tryParse(t.text.trim()) ?? fallback;
    final weight = double.tryParse(_weight.text.trim()) ?? s.weightKg;
    await ref.read(settingsProvider.notifier).save(s.copyWith(
          goal: _goal,
          activity: _activity,
          weightKg: weight,
          targets: Targets(
            calories: parse(_cal, s.targets.calories),
            proteinG: parse(_p, s.targets.proteinG),
            carbsG: parse(_c, s.targets.carbsG),
            fatG: parse(_f, s.targets.fatG),
          ),
        ));
    if (mounted) Navigator.pop(context);
  }

  void _recalculate() {
    final weight = double.tryParse(_weight.text.trim());
    if (weight == null || _goal == null || _activity == null) return;
    final t = calculateTargets(
        goal: _goal!, activity: _activity!, weightKg: weight);
    setState(() {
      _cal.text = '${t.calories}';
      _p.text = '${t.proteinG}';
      _c.text = '${t.carbsG}';
      _f.text = '${t.fatG}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    if (settings == null) return const Scaffold();
    _fill(settings);
    return Scaffold(
      appBar: AppBar(title: const Text('TARGETS')),
      body: LedgerBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const MonoLabel('Daily targets', size: 12),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _num(_cal, 'Calories')),
              const SizedBox(width: 12),
              Expanded(child: _num(_p, 'Protein g')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _num(_c, 'Carbs g')),
              const SizedBox(width: 12),
              Expanded(child: _num(_f, 'Fat g')),
            ]),
            const SizedBox(height: 24),
            const MonoLabel('Or recalculate', size: 12),
            const SizedBox(height: 8),
            DropdownButtonFormField<Goal>(
              initialValue: _goal,
              decoration: const InputDecoration(labelText: 'Goal'),
              items: const [
                DropdownMenuItem(value: Goal.cut, child: Text('Cut')),
                DropdownMenuItem(value: Goal.maintain, child: Text('Maintain')),
                DropdownMenuItem(value: Goal.bulk, child: Text('Bulk')),
              ],
              onChanged: (v) => setState(() => _goal = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ActivityLevel>(
              initialValue: _activity,
              decoration: const InputDecoration(labelText: 'Activity'),
              items: const [
                DropdownMenuItem(
                    value: ActivityLevel.sedentary, child: Text('Sedentary')),
                DropdownMenuItem(
                    value: ActivityLevel.light, child: Text('Light')),
                DropdownMenuItem(
                    value: ActivityLevel.moderate, child: Text('Moderate')),
                DropdownMenuItem(
                    value: ActivityLevel.veryActive,
                    child: Text('Very active')),
              ],
              onChanged: (v) => setState(() => _activity = v),
            ),
            const SizedBox(height: 12),
            _num(_weight, 'Weight kg'),
            const SizedBox(height: 12),
            StampButton(
                label: 'Recalculate targets',
                primary: false,
                onPressed: _recalculate),
            const SizedBox(height: 24),
            StampButton(label: 'Save', onPressed: () => _save(settings)),
          ],
        ),
      ),
    );
  }

  Widget _num(TextEditingController t, String label) => TextField(
        controller: t,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontFamily: monoFont),
        decoration: InputDecoration(labelText: label),
      );
}
