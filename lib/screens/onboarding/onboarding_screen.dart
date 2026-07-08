import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../logic/targets.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';

/// First launch goes straight here — no login, no signup, ever.
/// Three quick questions, then calorie/macro targets are auto-calculated
/// (and adjustable later in More > Targets).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  Goal? _goal;
  ActivityLevel? _activity;
  final _weightCtrl = TextEditingController();
  Targets? _preview;

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  double? get _weightKg => double.tryParse(_weightCtrl.text.trim());

  void _next() {
    if (_step == 2) {
      final w = _weightKg;
      if (w == null || w <= 0) return;
      _preview = calculateTargets(
          goal: _goal!, activity: _activity!, weightKg: w);
    }
    setState(() => _step++);
  }

  Future<void> _finish() async {
    final s = AppSettings.defaults.copyWith(
      onboarded: true,
      goal: _goal,
      activity: _activity,
      weightKg: _weightKg,
      targets: _preview,
    );
    await ref.read(settingsProvider.notifier).save(s);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Scaffold(
      body: LedgerBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text('GYM LEDGER',
                    style: TextStyle(
                        fontFamily: displayFont, fontSize: 44, color: c.accent)),
                const MonoLabel('Your data never leaves your phone'),
                const SizedBox(height: 32),
                Expanded(child: _buildStep(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _choiceStep<Goal>(
          title: "What's the goal?",
          values: Goal.values,
          selected: _goal,
          label: (g) => switch (g) {
            Goal.cut => 'CUT — lose fat',
            Goal.maintain => 'MAINTAIN — hold steady',
            Goal.bulk => 'BULK — build mass',
          },
          onSelect: (g) => setState(() => _goal = g),
          canContinue: _goal != null,
        );
      case 1:
        return _choiceStep<ActivityLevel>(
          title: 'How active are you outside the gym?',
          values: ActivityLevel.values,
          selected: _activity,
          label: (a) => switch (a) {
            ActivityLevel.sedentary => 'SEDENTARY — desk life',
            ActivityLevel.light => 'LIGHT — some walking',
            ActivityLevel.moderate => 'MODERATE — on my feet often',
            ActivityLevel.veryActive => 'VERY ACTIVE — physical job',
          },
          onSelect: (a) => setState(() => _activity = a),
          canContinue: _activity != null,
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Current weight?',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextField(
              controller: _weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontFamily: monoFont, fontSize: 24),
              decoration: const InputDecoration(
                  labelText: 'Weight (kg)', suffixText: 'kg'),
              onChanged: (_) => setState(() {}),
            ),
            const Spacer(),
            StampButton(
              label: 'Calculate my targets',
              onPressed:
                  (_weightKg != null && _weightKg! > 0) ? _next : null,
            ),
          ],
        );
      default:
        final t = _preview!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your daily targets',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const MonoLabel('Adjustable any time in More › Targets'),
            const SizedBox(height: 24),
            LedgerCard(
              child: Column(
                children: [
                  PixelNumber('${t.calories}', size: 72),
                  const MonoLabel('kcal / day', size: 13),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _macro(context, 'PROTEIN', t.proteinG),
                      _macro(context, 'CARBS', t.carbsG),
                      _macro(context, 'FAT', t.fatG),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            StampButton(label: 'Open the ledger', onPressed: _finish),
          ],
        );
    }
  }

  Widget _macro(BuildContext context, String label, int grams) => Column(
        children: [
          PixelNumber('${grams}g', size: 34),
          MonoLabel(label),
        ],
      );

  Widget _choiceStep<T>({
    required String title,
    required List<T> values,
    required T? selected,
    required String Function(T) label,
    required void Function(T) onSelect,
    required bool canContinue,
  }) {
    final c = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        for (final v in values) ...[
          LedgerCard(
            onTap: () => onSelect(v),
            borderColor: v == selected ? c.accent : null,
            child: Row(
              children: [
                Icon(
                  v == selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: v == selected ? c.accent : c.inkFaint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label(v),
                      style:
                          const TextStyle(fontFamily: monoFont, fontSize: 15)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Spacer(),
        StampButton(label: 'Next', onPressed: canContinue ? _next : null),
      ],
    );
  }
}
