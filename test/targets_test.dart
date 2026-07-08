import 'package:flutter_test/flutter_test.dart';
import 'package:gym_ledger/data/models.dart';
import 'package:gym_ledger/logic/targets.dart';

void main() {
  test('maintain at moderate: 35 kcal/kg, 1.6 g/kg protein, 3 g/kg carbs', () {
    final t = calculateTargets(
        goal: Goal.maintain,
        activity: ActivityLevel.moderate,
        weightKg: 80);
    expect(t.calories, 2800);
    expect(t.proteinG, 128); // 1.6 g/kg
    expect(t.carbsG, 240); // 3 g/kg
    expect(t.fatG, ((2800 - 128 * 4 - 240 * 4) / 9).round());
  });

  test('cut: calories -20%, protein rises to 2.2 g/kg', () {
    final t = calculateTargets(
        goal: Goal.cut, activity: ActivityLevel.moderate, weightKg: 80);
    expect(t.calories, (80 * 35 * 0.8).round());
    expect(t.proteinG, (80 * 2.2).round()); // 176
    expect(t.carbsG, 240); // carbs still 3 g/kg at moderate
  });

  test('bulk: +10% calories, protein stays 1.6 g/kg', () {
    final t = calculateTargets(
        goal: Goal.bulk, activity: ActivityLevel.sedentary, weightKg: 70);
    expect(t.calories, (70 * 26 * 1.1).round());
    expect(t.proteinG, (70 * 1.6).round()); // 112
    expect(t.carbsG, 140); // 2 g/kg sedentary
  });

  test('carbs scale with activity: 2 / 2.5 / 3 / 3.5 g/kg', () {
    Targets at(ActivityLevel a) => calculateTargets(
        goal: Goal.maintain, activity: a, weightKg: 100);
    expect(at(ActivityLevel.sedentary).carbsG, 200);
    expect(at(ActivityLevel.light).carbsG, 250);
    expect(at(ActivityLevel.moderate).carbsG, 300);
    expect(at(ActivityLevel.veryActive).carbsG, 350);
  });

  test('macros account for all calories (fat is the remainder)', () {
    final t = calculateTargets(
        goal: Goal.maintain, activity: ActivityLevel.veryActive, weightKg: 90);
    final macroCal = t.proteinG * 4 + t.carbsG * 4 + t.fatG * 9;
    expect((macroCal - t.calories).abs(), lessThan(10));
  });

  test('fat never goes negative even on a hard sedentary cut', () {
    final t = calculateTargets(
        goal: Goal.cut, activity: ActivityLevel.sedentary, weightKg: 50);
    expect(t.fatG, greaterThanOrEqualTo(0));
  });
}
