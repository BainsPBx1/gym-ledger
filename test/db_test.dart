import 'package:flutter_test/flutter_test.dart';
import 'package:gym_ledger/data/daos.dart';
import 'package:gym_ledger/data/db.dart';
import 'package:gym_ledger/data/models.dart';
import 'package:gym_ledger/logic/archival.dart';
import 'package:gym_ledger/logic/stats.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;

  setUp(() async {
    db = await AppDatabase.openAt(inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  group('locked sets', () {
    late int sessionId;
    late int setId;

    setUp(() async {
      final dao = WorkoutDao(db);
      sessionId = await dao.startSession(WorkoutSession(
          templateName: 'Push', startedAt: DateTime.now()));
      setId = await dao.logSet(SetLog(
          sessionId: sessionId,
          exercise: 'Bench Press',
          weightKg: 80,
          reps: 8,
          loggedAt: DateTime.now()));
    });

    test('database triggers reject UPDATE on set_logs', () async {
      expect(
        () => db.db.update('set_logs', {'weight_kg': 999},
            where: 'id = ?', whereArgs: [setId]),
        throwsA(anything),
      );
      final sets = await WorkoutDao(db).setsForSession(sessionId);
      expect(sets.single.weightKg, 80);
    });

    test('database triggers reject DELETE on set_logs', () async {
      expect(
        () => db.db.delete('set_logs', where: 'id = ?', whereArgs: [setId]),
        throwsA(anything),
      );
      final sets = await WorkoutDao(db).setsForSession(sessionId);
      expect(sets, hasLength(1));
    });

    test('last set pre-fills the next weight', () async {
      final dao = WorkoutDao(db);
      await dao.logSet(SetLog(
          sessionId: sessionId,
          exercise: 'Bench Press',
          weightKg: 82.5,
          reps: 6,
          loggedAt: DateTime.now().add(const Duration(minutes: 3))));
      final last = await dao.lastSetFor('Bench Press');
      expect(last!.weightKg, 82.5);
    });
  });

  group('food library', () {
    test('barcode is a local key into the library', () async {
      final dao = FoodDao(db);
      await dao.insert(Food(
          name: 'Protein Bar',
          barcode: '123456789',
          calories: 210,
          proteinG: 20,
          carbsG: 22,
          fatG: 7,
          createdAt: DateTime.now()));
      final hit = await dao.byBarcode('123456789');
      expect(hit!.name, 'Protein Bar');
      expect(await dao.byBarcode('unknown'), isNull);
    });

    test('search matches name and tags', () async {
      final dao = FoodDao(db);
      await dao.insert(Food(
          name: 'Overnight Oats',
          tags: 'breakfast,prep',
          calories: 350,
          proteinG: 25,
          carbsG: 45,
          fatG: 8,
          createdAt: DateTime.now()));
      expect(await dao.search('oats'), hasLength(1));
      expect(await dao.search('breakfast'), hasLength(1));
      expect(await dao.search('dinner'), isEmpty);
    });
  });

  group('monthly aggregates', () {
    const targets =
        Targets(calories: 2000, proteinG: 150, carbsG: 200, fatG: 55);

    test('missed vs under-target vs on-target days', () async {
      final meals = MealDao(db);
      final now = DateTime.now();
      final first = DateTime(now.year, now.month, 1);
      // Day 1: on target (within 10% of calories, protein >= 80%).
      await meals.insert(MealLog(
          name: 'big day',
          calories: 2000,
          proteinG: 150,
          carbsG: 200,
          fatG: 55,
          loggedAt: first.add(const Duration(hours: 12))));
      // Day 2: logged but way under.
      if (now.day >= 2) {
        await meals.insert(MealLog(
            name: 'small day',
            calories: 600,
            proteinG: 30,
            carbsG: 60,
            fatG: 20,
            loggedAt: first.add(const Duration(days: 1, hours: 12))));
      }

      final days = await StatsDao(db).daysForMonth(first, targets);
      expect(days.first.status, DayStatus.onTarget);
      if (now.day >= 2) {
        expect(days[1].status, DayStatus.loggedUnderTarget);
      }
      if (now.day >= 3) {
        // Day 3 has no log at all: missed, rendered below the baseline.
        expect(days[2].status, DayStatus.missed);
      }
      expect(days.length, now.day); // current month runs up to today
    });

    test('workout days are flagged', () async {
      final wd = WorkoutDao(db);
      final now = DateTime.now();
      await wd.startSession(WorkoutSession(
          templateName: 'Pull',
          startedAt: DateTime(now.year, now.month, now.day, 18)));
      final days = await StatsDao(db)
          .daysForMonth(DateTime(now.year, now.month, 1), targets);
      expect(days.last.workedOut, isTrue);
      expect(await StatsDao(db).workedOutToday(), isTrue);
    });
  });

  group('logging streak', () {
    test('counts consecutive days back from today', () async {
      final meals = MealDao(db);
      final now = DateTime.now();
      for (var i = 0; i < 3; i++) {
        await meals.insert(MealLog(
            name: 'meal',
            calories: 500,
            proteinG: 30,
            carbsG: 50,
            fatG: 15,
            loggedAt: DateTime(now.year, now.month, now.day, 12)
                .subtract(Duration(days: i))));
      }
      expect(await StatsDao(db).loggingStreak(), 3);
    });

    test('unlogged today does not break the streak', () async {
      final meals = MealDao(db);
      final now = DateTime.now();
      for (var i = 1; i <= 2; i++) {
        await meals.insert(MealLog(
            name: 'meal',
            calories: 500,
            proteinG: 30,
            carbsG: 50,
            fatG: 15,
            loggedAt: DateTime(now.year, now.month, now.day, 12)
                .subtract(Duration(days: i))));
      }
      expect(await StatsDao(db).loggingStreak(), 2);
    });

    test('gap resets the streak', () async {
      final meals = MealDao(db);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      await meals.insert(MealLog(
          name: 'meal',
          calories: 500,
          proteinG: 30,
          carbsG: 50,
          fatG: 15,
          loggedAt: today));
      await meals.insert(MealLog(
          name: 'old meal',
          calories: 500,
          proteinG: 30,
          carbsG: 50,
          fatG: 15,
          loggedAt: today.subtract(const Duration(days: 5))));
      expect(await StatsDao(db).loggingStreak(), 1);
    });
  });

  group('archival', () {
    test('old meals collapse into monthly summaries; recent ones stay',
        () async {
      final meals = MealDao(db);
      final now = DateTime(2026, 7, 6, 12);
      // 14 months old — two meals on separate days.
      await meals.insert(MealLog(
          name: 'old 1',
          calories: 700,
          proteinG: 40,
          carbsG: 80,
          fatG: 20,
          loggedAt: DateTime(2025, 5, 3, 12)));
      await meals.insert(MealLog(
          name: 'old 2',
          calories: 300,
          proteinG: 20,
          carbsG: 30,
          fatG: 10,
          loggedAt: DateTime(2025, 5, 4, 12)));
      // Recent meal stays.
      await meals.insert(MealLog(
          name: 'recent',
          calories: 500,
          proteinG: 35,
          carbsG: 40,
          fatG: 18,
          loggedAt: DateTime(2026, 7, 1, 12)));

      final archived = await ArchivalService(db).run(now: now);
      expect(archived, 2);

      final remaining = await meals.all();
      expect(remaining.single.name, 'recent');

      final summaries = await db.db.query('monthly_summaries');
      final s = MonthlySummary.fromMap(summaries.single);
      expect(s.month, '2025-05');
      expect(s.daysLogged, 2);
      expect(s.totalCalories, 1000);
      expect(s.mealCount, 2);
    });

    test('workout history is never archived', () async {
      final wd = WorkoutDao(db);
      final old = DateTime(2024, 1, 10, 18);
      final sid = await wd.startSession(
          WorkoutSession(templateName: 'Legs', startedAt: old));
      await wd.logSet(SetLog(
          sessionId: sid,
          exercise: 'Squat',
          weightKg: 100,
          reps: 5,
          loggedAt: old));
      await ArchivalService(db).run(now: DateTime(2026, 7, 6));
      expect(await wd.allSets(), hasLength(1));
      expect(await wd.sessions(), hasLength(1));
    });

    test('running twice is idempotent', () async {
      final meals = MealDao(db);
      await meals.insert(MealLog(
          name: 'old',
          calories: 400,
          proteinG: 20,
          carbsG: 40,
          fatG: 12,
          loggedAt: DateTime(2025, 2, 10, 12)));
      final now = DateTime(2026, 7, 6);
      await ArchivalService(db).run(now: now);
      await ArchivalService(db).run(now: now);
      final s = MonthlySummary.fromMap(
          (await db.db.query('monthly_summaries')).single);
      expect(s.totalCalories, 400);
      expect(s.mealCount, 1);
    });
  });

  group('settings round-trip', () {
    test('saved settings load back identically', () async {
      final dao = SettingsDao(db);
      final s = AppSettings.defaults.copyWith(
        onboarded: true,
        goal: Goal.cut,
        activity: ActivityLevel.light,
        weightKg: 82.5,
        targets:
            const Targets(calories: 2100, proteinG: 180, carbsG: 190, fatG: 58),
        themeMode: 'dark',
        biometricLock: true,
      );
      await dao.save(s);
      final loaded = await dao.load();
      expect(loaded.onboarded, isTrue);
      expect(loaded.goal, Goal.cut);
      expect(loaded.activity, ActivityLevel.light);
      expect(loaded.weightKg, 82.5);
      expect(loaded.targets.calories, 2100);
      expect(loaded.themeMode, 'dark');
      expect(loaded.biometricLock, isTrue);
    });
  });

  group('workout plan (splits)', () {
    test('split -> weekday exercises -> preset sets round-trip', () async {
      final dao = SplitDao(db);
      final splitId = await dao.insertSplit(const Split(name: 'PPL'));
      final exId = await dao.insertExercise(PlanExercise(
          splitId: splitId,
          weekday: 1, // Monday
          name: 'Bench Press',
          restSeconds: 90));
      await dao.replaceSets(exId, const [
        PlanSet(exerciseId: 0, setIndex: 0, targetWeightKg: 20, targetReps: 14),
        PlanSet(exerciseId: 0, setIndex: 1, targetWeightKg: 25, targetReps: 10),
        PlanSet(exerciseId: 0, setIndex: 2, targetWeightKg: 35, targetReps: 8),
      ]);

      final monday = await dao.exercisesFor(splitId, 1);
      expect(monday.single.name, 'Bench Press');
      expect(await dao.exercisesFor(splitId, 2), isEmpty); // Tuesday empty

      final sets = await dao.setsFor(exId);
      expect(sets, hasLength(3));
      expect(sets[0].targetWeightKg, 20);
      expect(sets[0].targetReps, 14);
      expect(sets[2].targetWeightKg, 35);

      expect(await dao.plannedWeekdays(splitId), {1});

      // Editing replaces wholesale.
      await dao.replaceSets(exId, const [
        PlanSet(exerciseId: 0, setIndex: 0, targetWeightKg: 22.5, targetReps: 12),
      ]);
      expect((await dao.setsFor(exId)).single.targetWeightKg, 22.5);
    });

    test('deleting a split cascades its plan but keeps logged history',
        () async {
      final dao = SplitDao(db);
      final wd = WorkoutDao(db);
      final splitId = await dao.insertSplit(const Split(name: 'Bro split'));
      final exId = await dao.insertExercise(PlanExercise(
          splitId: splitId, weekday: 3, name: 'Curls'));
      await dao.replaceSets(exId, const [
        PlanSet(exerciseId: 0, setIndex: 0, targetWeightKg: 15, targetReps: 12),
      ]);
      final sid = await wd.startSession(WorkoutSession(
          templateName: 'Bro split · Wednesday', startedAt: DateTime.now()));
      await wd.logSet(SetLog(
          sessionId: sid,
          exercise: 'Curls',
          weightKg: 15,
          reps: 12,
          loggedAt: DateTime.now()));

      await dao.deleteSplit(splitId);
      expect(await dao.splits(), isEmpty);
      expect(await dao.setsFor(exId), isEmpty); // cascade
      expect(await wd.allSets(), hasLength(1)); // history untouched
    });
  });

  group('PRs', () {
    test('scoreboard orders most recent first and tracks best', () async {
      final dao = PrDao(db);
      await dao.insert(PrEntry(
          exercise: 'Deadlift', weightKg: 180, date: DateTime(2026, 5, 1)));
      await dao.insert(PrEntry(
          exercise: 'Deadlift', weightKg: 190, date: DateTime(2026, 7, 1)));
      final all = await dao.all();
      expect(all.first.weightKg, 190);
      expect(await dao.bestFor('Deadlift'), 190);
      expect(await dao.bestFor('Bench'), isNull);
    });
  });
}
