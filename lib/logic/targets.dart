import '../data/models.dart';

/// Calorie/macro targets from the three onboarding answers.
///
/// Only goal, activity level, and body weight are collected (by design — the
/// onboarding is 3 quick questions), so maintenance is estimated with
/// bodyweight multipliers rather than a BMR formula that would need
/// age/height/sex:
///   sedentary 26, light 31, moderate 35, very active 40 kcal per kg.
/// Goal adjustment: cut -20%, bulk +10%.
/// Protein: 2.2 g/kg on a cut, 1.8 g/kg otherwise. Fat: 25% of calories.
/// Carbs: remaining calories. All of it is editable later in settings.
Targets calculateTargets({
  required Goal goal,
  required ActivityLevel activity,
  required double weightKg,
}) {
  const kcalPerKg = {
    ActivityLevel.sedentary: 26.0,
    ActivityLevel.light: 31.0,
    ActivityLevel.moderate: 35.0,
    ActivityLevel.veryActive: 40.0,
  };
  const goalFactor = {
    Goal.cut: 0.80,
    Goal.maintain: 1.0,
    Goal.bulk: 1.10,
  };

  final maintenance = weightKg * kcalPerKg[activity]!;
  final calories = (maintenance * goalFactor[goal]!).round();

  final proteinPerKg = goal == Goal.cut ? 2.2 : 1.8;
  final proteinG = (weightKg * proteinPerKg).round();
  final fatG = (calories * 0.25 / 9).round();
  final carbsG = ((calories - proteinG * 4 - fatG * 9) / 4).round().clamp(0, 10000);

  return Targets(
    calories: calories,
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
  );
}
