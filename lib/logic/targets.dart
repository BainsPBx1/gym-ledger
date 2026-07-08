import '../data/models.dart';

/// Calorie/macro targets from the three onboarding answers.
///
/// Only goal, activity level, and body weight (kg) are collected — the
/// onboarding stays at 3 quick questions — so everything is bodyweight-based:
///
/// Calories: maintenance = kcal/kg by activity (sedentary 26, light 31,
///   moderate 35, very active 40), then cut -20% / bulk +10%.
/// Protein: 2.2 g/kg on a cut; 1.6 g/kg on maintain or bulk.
/// Carbs: by activity — sedentary 2, light 2.5, moderate 3,
///   very active 3.5 g/kg.
/// Fat: whatever calories remain after protein and carbs, at 9 kcal/g.
///
/// All of it is editable later in More > Targets.
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
  const carbsPerKg = {
    ActivityLevel.sedentary: 2.0,
    ActivityLevel.light: 2.5,
    ActivityLevel.moderate: 3.0,
    ActivityLevel.veryActive: 3.5,
  };

  final maintenance = weightKg * kcalPerKg[activity]!;
  final calories = (maintenance * goalFactor[goal]!).round();

  final proteinPerKg = goal == Goal.cut ? 2.2 : 1.6;
  final proteinG = (weightKg * proteinPerKg).round();
  final carbsG = (weightKg * carbsPerKg[activity]!).round();
  final fatG =
      ((calories - proteinG * 4 - carbsG * 4) / 9).round().clamp(0, 10000);

  return Targets(
    calories: calories,
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
  );
}
