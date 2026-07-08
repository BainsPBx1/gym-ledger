import 'package:flutter_test/flutter_test.dart';
import 'package:gym_ledger/data/models.dart';
import 'package:gym_ledger/logic/targets.dart';

void main() {
  test('maintain at moderate activity uses 35 kcal/kg', () {
    final t = calculateTargets(
        goal: Goal.maintain,
        activity: ActivityLevel.moderate,
        weightKg: 80);
    expect(t.calories, 2800);
    expect(t.proteinG, 144); // 1.8 g/kg
    expect(t.fatG, (2800 * 0.25 / 9).round());
  });

  test('cut trims calories 20% and raises protein to 2.2 g/kg', () {
    final t = calculateTargets(
        goal: Goal.cut, activity: ActivityLevel.moderate, weightKg: 80);
    expect(t.calories, (80 * 35 * 0.8).round());
    expect(t.proteinG, (80 * 2.2).round());
  });

  test('bulk adds 10%', () {
    final t = calculateTargets(
        goal: Goal.bulk, activity: ActivityLevel.sedentary, weightKg: 70);
    expect(t.calories, (70 * 26 * 1.1).round());
  });

  test('macros roughly account for all calories', () {
    final t = calculateTargets(
        goal: Goal.maintain, activity: ActivityLevel.veryActive, weightKg: 90);
    final macroCal = t.proteinG * 4 + t.carbsG * 4 + t.fatG * 9;
    expect((macroCal - t.calories).abs(), lessThan(10));
  });
}
