import 'package:flutter/foundation.dart';

enum Goal { cut, maintain, bulk }

enum ActivityLevel { sedentary, light, moderate, veryActive }

@immutable
class Targets {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  const Targets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

@immutable
class AppSettings {
  final bool onboarded;
  final Goal goal;
  final ActivityLevel activity;
  final double weightKg;
  final Targets targets;
  final String themeMode; // 'system' | 'light' | 'dark'
  final bool biometricLock;
  final DateTime? lastExportAt;

  const AppSettings({
    required this.onboarded,
    required this.goal,
    required this.activity,
    required this.weightKg,
    required this.targets,
    required this.themeMode,
    required this.biometricLock,
    required this.lastExportAt,
  });

  static const defaults = AppSettings(
    onboarded: false,
    goal: Goal.maintain,
    activity: ActivityLevel.moderate,
    weightKg: 75,
    targets: Targets(calories: 2600, proteinG: 135, carbsG: 293, fatG: 72),
    themeMode: 'system',
    biometricLock: false,
    lastExportAt: null,
  );

  AppSettings copyWith({
    bool? onboarded,
    Goal? goal,
    ActivityLevel? activity,
    double? weightKg,
    Targets? targets,
    String? themeMode,
    bool? biometricLock,
    DateTime? lastExportAt,
  }) {
    return AppSettings(
      onboarded: onboarded ?? this.onboarded,
      goal: goal ?? this.goal,
      activity: activity ?? this.activity,
      weightKg: weightKg ?? this.weightKg,
      targets: targets ?? this.targets,
      themeMode: themeMode ?? this.themeMode,
      biometricLock: biometricLock ?? this.biometricLock,
      lastExportAt: lastExportAt ?? this.lastExportAt,
    );
  }
}

@immutable
class Food {
  final int? id;
  final String name;
  final String? barcode; // local ID/hash only, never looked up externally
  final String tags; // comma-separated user tags
  final double calories; // per serving
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String servingDesc;
  final DateTime createdAt;

  const Food({
    this.id,
    required this.name,
    this.barcode,
    this.tags = '',
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.servingDesc = '1 serving',
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'tags': tags,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'serving_desc': servingDesc,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static Food fromMap(Map<String, Object?> m) => Food(
        id: m['id'] as int?,
        name: m['name'] as String,
        barcode: m['barcode'] as String?,
        tags: (m['tags'] as String?) ?? '',
        calories: (m['calories'] as num).toDouble(),
        proteinG: (m['protein_g'] as num).toDouble(),
        carbsG: (m['carbs_g'] as num).toDouble(),
        fatG: (m['fat_g'] as num).toDouble(),
        servingDesc: (m['serving_desc'] as String?) ?? '1 serving',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}

/// A logged meal. Nutrients are snapshotted at log time so later edits to a
/// library food never rewrite history.
@immutable
class MealLog {
  final int? id;
  final int? foodId;
  final String name;
  final double servings;
  final double calories; // totals for [servings]
  final double proteinG;
  final double carbsG;
  final double fatG;
  final DateTime loggedAt;
  final String? photoPath;
  final String? photoHash; // perceptual hash for offline photo matching

  const MealLog({
    this.id,
    this.foodId,
    required this.name,
    this.servings = 1,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.loggedAt,
    this.photoPath,
    this.photoHash,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'food_id': foodId,
        'name': name,
        'servings': servings,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'logged_at': loggedAt.millisecondsSinceEpoch,
        'photo_path': photoPath,
        'photo_hash': photoHash,
      };

  static MealLog fromMap(Map<String, Object?> m) => MealLog(
        id: m['id'] as int?,
        foodId: m['food_id'] as int?,
        name: m['name'] as String,
        servings: (m['servings'] as num).toDouble(),
        calories: (m['calories'] as num).toDouble(),
        proteinG: (m['protein_g'] as num).toDouble(),
        carbsG: (m['carbs_g'] as num).toDouble(),
        fatG: (m['fat_g'] as num).toDouble(),
        loggedAt: DateTime.fromMillisecondsSinceEpoch(m['logged_at'] as int),
        photoPath: m['photo_path'] as String?,
        photoHash: m['photo_hash'] as String?,
      );
}

/// A training split the user builds, e.g. "PPL" or "Bro split". Each split
/// plans exercises per weekday; the whole thing is preset before the gym.
@immutable
class Split {
  final int? id;
  final String name;
  final int position;
  const Split({this.id, required this.name, this.position = 0});

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'position': position};
  static Split fromMap(Map<String, Object?> m) => Split(
      id: m['id'] as int?,
      name: m['name'] as String,
      position: m['position'] as int);
}

/// One exercise planned on a specific weekday of a split, with the rest
/// period to run between its sets.
@immutable
class PlanExercise {
  final int? id;
  final int splitId;
  final int weekday; // 1 = Monday ... 7 = Sunday (DateTime.weekday)
  final String name;
  final int position;
  final int restSeconds;
  const PlanExercise({
    this.id,
    required this.splitId,
    required this.weekday,
    required this.name,
    this.position = 0,
    this.restSeconds = 90,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'split_id': splitId,
        'weekday': weekday,
        'name': name,
        'position': position,
        'rest_seconds': restSeconds,
      };
  static PlanExercise fromMap(Map<String, Object?> m) => PlanExercise(
        id: m['id'] as int?,
        splitId: m['split_id'] as int,
        weekday: m['weekday'] as int,
        name: m['name'] as String,
        position: m['position'] as int,
        restSeconds: m['rest_seconds'] as int,
      );
}

/// A preset set within a planned exercise: target weight and reps, entered
/// ahead of time. During the guided workout these pre-fill the inputs and
/// the user only adjusts the actuals.
@immutable
class PlanSet {
  final int? id;
  final int exerciseId;
  final int setIndex; // 0-based order
  final double targetWeightKg;
  final int targetReps;
  const PlanSet({
    this.id,
    required this.exerciseId,
    required this.setIndex,
    required this.targetWeightKg,
    required this.targetReps,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'exercise_id': exerciseId,
        'set_index': setIndex,
        'target_weight_kg': targetWeightKg,
        'target_reps': targetReps,
      };
  static PlanSet fromMap(Map<String, Object?> m) => PlanSet(
        id: m['id'] as int?,
        exerciseId: m['exercise_id'] as int,
        setIndex: m['set_index'] as int,
        targetWeightKg: (m['target_weight_kg'] as num).toDouble(),
        targetReps: m['target_reps'] as int,
      );
}

@immutable
class WorkoutSession {
  final int? id;
  final int? templateId;
  final String templateName;
  final DateTime startedAt;
  final DateTime? endedAt;
  const WorkoutSession({
    this.id,
    this.templateId,
    required this.templateName,
    required this.startedAt,
    this.endedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'template_id': templateId,
        'template_name': templateName,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
      };
  static WorkoutSession fromMap(Map<String, Object?> m) => WorkoutSession(
        id: m['id'] as int?,
        templateId: m['template_id'] as int?,
        templateName: m['template_name'] as String,
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(m['started_at'] as int),
        endedAt: m['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['ended_at'] as int),
      );
}

/// A logged set. Locked on save: the DAO exposes insert only — no update or
/// delete path exists anywhere in the app, by hard product requirement.
@immutable
class SetLog {
  final int? id;
  final int sessionId;
  final String exercise;
  final double weightKg;
  final int reps;
  final DateTime loggedAt;
  const SetLog({
    this.id,
    required this.sessionId,
    required this.exercise,
    required this.weightKg,
    required this.reps,
    required this.loggedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'exercise': exercise,
        'weight_kg': weightKg,
        'reps': reps,
        'logged_at': loggedAt.millisecondsSinceEpoch,
      };
  static SetLog fromMap(Map<String, Object?> m) => SetLog(
        id: m['id'] as int?,
        sessionId: m['session_id'] as int,
        exercise: m['exercise'] as String,
        weightKg: (m['weight_kg'] as num).toDouble(),
        reps: m['reps'] as int,
        loggedAt: DateTime.fromMillisecondsSinceEpoch(m['logged_at'] as int),
      );
}

@immutable
class PrEntry {
  final int? id;
  final String exercise;
  final double weightKg;
  final DateTime date;
  final String? mediaPath;
  final String? mediaType; // 'photo' | 'video'
  const PrEntry({
    this.id,
    required this.exercise,
    required this.weightKg,
    required this.date,
    this.mediaPath,
    this.mediaType,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'exercise': exercise,
        'weight_kg': weightKg,
        'date': date.millisecondsSinceEpoch,
        'media_path': mediaPath,
        'media_type': mediaType,
      };
  static PrEntry fromMap(Map<String, Object?> m) => PrEntry(
        id: m['id'] as int?,
        exercise: m['exercise'] as String,
        weightKg: (m['weight_kg'] as num).toDouble(),
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        mediaPath: m['media_path'] as String?,
        mediaType: m['media_type'] as String?,
      );
}

/// A recurring gym time window, e.g. 5-7 PM Mon/Wed/Fri. If no workout has
/// been started by [remindAfterMinutes] into the window, a local notification
/// fires. No location involved.
@immutable
class GymWindow {
  final int? id;
  final int daysMask; // bit 0 = Monday ... bit 6 = Sunday
  final int startMinute; // minutes since midnight
  final int endMinute;
  final int remindAfterMinutes; // offset into window before reminder fires
  final bool enabled;
  const GymWindow({
    this.id,
    required this.daysMask,
    required this.startMinute,
    required this.endMinute,
    this.remindAfterMinutes = 30,
    this.enabled = true,
  });

  bool appliesOn(int weekday) => (daysMask & (1 << (weekday - 1))) != 0;

  Map<String, Object?> toMap() => {
        'id': id,
        'days_mask': daysMask,
        'start_minute': startMinute,
        'end_minute': endMinute,
        'remind_after_minutes': remindAfterMinutes,
        'enabled': enabled ? 1 : 0,
      };
  static GymWindow fromMap(Map<String, Object?> m) => GymWindow(
        id: m['id'] as int?,
        daysMask: m['days_mask'] as int,
        startMinute: m['start_minute'] as int,
        endMinute: m['end_minute'] as int,
        remindAfterMinutes: m['remind_after_minutes'] as int,
        enabled: (m['enabled'] as int) != 0,
      );
}

/// Archived month of meal-level detail (rows older than ~12 months collapse
/// into one of these).
@immutable
class MonthlySummary {
  final String month; // 'yyyy-MM'
  final int daysLogged;
  final double totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final int mealCount;
  const MonthlySummary({
    required this.month,
    required this.daysLogged,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.mealCount,
  });

  Map<String, Object?> toMap() => {
        'month': month,
        'days_logged': daysLogged,
        'total_calories': totalCalories,
        'total_protein_g': totalProteinG,
        'total_carbs_g': totalCarbsG,
        'total_fat_g': totalFatG,
        'meal_count': mealCount,
      };
  static MonthlySummary fromMap(Map<String, Object?> m) => MonthlySummary(
        month: m['month'] as String,
        daysLogged: m['days_logged'] as int,
        totalCalories: (m['total_calories'] as num).toDouble(),
        totalProteinG: (m['total_protein_g'] as num).toDouble(),
        totalCarbsG: (m['total_carbs_g'] as num).toDouble(),
        totalFatG: (m['total_fat_g'] as num).toDouble(),
        mealCount: m['meal_count'] as int,
      );
}

/// One day on the monthly progress graph.
enum DayStatus { missed, loggedUnderTarget, onTarget }

@immutable
class DayAggregate {
  final DateTime day;
  final DayStatus status;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final bool workedOut;
  const DayAggregate({
    required this.day,
    required this.status,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.workedOut,
  });
}
