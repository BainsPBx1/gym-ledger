import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/daos.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../logic/stats.dart';
import '../services/biometric_service.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/photo_service.dart';
import '../services/storage_service.dart';

/// Overridden with the real database in main() before runApp.
final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

final settingsDaoProvider = Provider((ref) => SettingsDao(ref.watch(dbProvider)));
final foodDaoProvider = Provider((ref) => FoodDao(ref.watch(dbProvider)));
final mealDaoProvider = Provider((ref) => MealDao(ref.watch(dbProvider)));
final workoutDaoProvider = Provider((ref) => WorkoutDao(ref.watch(dbProvider)));
final splitDaoProvider = Provider((ref) => SplitDao(ref.watch(dbProvider)));
final prDaoProvider = Provider((ref) => PrDao(ref.watch(dbProvider)));
final gymWindowDaoProvider = Provider((ref) => GymWindowDao(ref.watch(dbProvider)));
final statsDaoProvider = Provider((ref) => StatsDao(ref.watch(dbProvider)));

final photoServiceProvider = Provider((ref) => PhotoService());
final ocrServiceProvider = Provider((ref) => OcrService());
final notificationServiceProvider = Provider((ref) => NotificationService());
final biometricServiceProvider = Provider((ref) => BiometricService());
final exportServiceProvider = Provider((ref) => ExportService(ref.watch(dbProvider)));
final storageServiceProvider = Provider((ref) => StorageService(ref.watch(dbProvider)));

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(settingsDaoProvider).load();

  Future<void> save(AppSettings s) async {
    await ref.read(settingsDaoProvider).save(s);
    state = AsyncData(s);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Bumped whenever meal data changes so day/graph views refresh.
final mealsVersionProvider = StateProvider<int>((ref) => 0);

/// Bumped whenever workout data changes.
final workoutsVersionProvider = StateProvider<int>((ref) => 0);

/// Bumped whenever PRs change.
final prsVersionProvider = StateProvider<int>((ref) => 0);

final dayLogsProvider =
    FutureProvider.family<List<MealLog>, DateTime>((ref, day) {
  ref.watch(mealsVersionProvider);
  return ref.watch(mealDaoProvider).forDay(day);
});

final loggingStreakProvider = FutureProvider<int>((ref) {
  ref.watch(mealsVersionProvider);
  return ref.watch(statsDaoProvider).loggingStreak();
});

final splitsProvider = FutureProvider<List<Split>>((ref) {
  ref.watch(workoutsVersionProvider);
  return ref.watch(splitDaoProvider).splits();
});

/// Exercises planned for (splitId, weekday).
final planExercisesProvider =
    FutureProvider.family<List<PlanExercise>, (int, int)>((ref, key) {
  ref.watch(workoutsVersionProvider);
  return ref.watch(splitDaoProvider).exercisesFor(key.$1, key.$2);
});

/// Preset sets of a planned exercise.
final planSetsProvider =
    FutureProvider.family<List<PlanSet>, int>((ref, exerciseId) {
  ref.watch(workoutsVersionProvider);
  return ref.watch(splitDaoProvider).setsFor(exerciseId);
});

/// Weekdays of a split that have anything planned (for day chips).
final plannedWeekdaysProvider =
    FutureProvider.family<Set<int>, int>((ref, splitId) {
  ref.watch(workoutsVersionProvider);
  return ref.watch(splitDaoProvider).plannedWeekdays(splitId);
});

final activeSessionProvider = FutureProvider<WorkoutSession?>((ref) {
  ref.watch(workoutsVersionProvider);
  return ref.watch(workoutDaoProvider).activeSession();
});

final prsProvider = FutureProvider<List<PrEntry>>((ref) {
  ref.watch(prsVersionProvider);
  return ref.watch(prDaoProvider).all();
});

final gymWindowsProvider = FutureProvider<List<GymWindow>>((ref) {
  ref.watch(workoutsVersionProvider);
  return ref.watch(gymWindowDaoProvider).all();
});

/// Currently selected split on the workout screen.
final selectedSplitProvider = StateProvider<int?>((ref) => null);

/// Currently selected weekday (1 = Monday ... 7 = Sunday); defaults to today.
final selectedWeekdayProvider =
    StateProvider<int>((ref) => DateTime.now().weekday);
