import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_ledger/app.dart';
import 'package:gym_ledger/data/db.dart';
import 'package:gym_ledger/state/providers.dart';
import 'package:gym_ledger/widgets/ledger_widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// End-to-end flows through the real widget tree with an in-memory database:
/// onboarding, meal logging, workout logging with locked sets and the rest
/// timer, PR celebration, and the monthly graph.
///
/// The FFI SQLite driver does real async I/O on another isolate, so each
/// test runs inside [WidgetTester.runAsync] and settles with real delays.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;

  /// Pump frames while letting real async (DB isolate) complete.
  Future<void> settle(WidgetTester tester, {int rounds = 12}) async {
    for (var i = 0; i < rounds; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    db = await AppDatabase.openAt(inMemoryDatabasePath);
    addTearDown(() => db.close());
    await tester.pumpWidget(ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: const GymLedgerApp(),
    ));
    await settle(tester);
  }

  Future<void> completeOnboarding(WidgetTester tester) async {
    // No login/signup — first launch lands directly in onboarding.
    expect(find.text('GYM LEDGER'), findsOneWidget);
    await tester.tap(find.textContaining('CUT'));
    await tester.pump();
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.tap(find.textContaining('MODERATE'));
    await tester.pump();
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '80');
    await tester.pump();
    await tester.tap(find.text('CALCULATE MY TARGETS'));
    await tester.pump();
    // cut @ 80kg moderate: 80*35*0.8 = 2240 kcal.
    expect(find.text('2240'), findsOneWidget);
    await tester.tap(find.text('OPEN THE LEDGER'));
    await settle(tester);
  }

  testWidgets('onboarding calculates targets and opens the app',
      (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);
      await completeOnboarding(tester);
      expect(find.text('Today'), findsOneWidget); // bottom nav
      expect(find.text('OF 2240'), findsOneWidget); // target on daily view
    });
  });

  testWidgets('create a food and log it; daily totals update', (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);
      await completeOnboarding(tester);

      await tester.tap(find.text('+ LOG A MEAL'));
      await settle(tester, rounds: 6);
      await tester.ensureVisible(find.text('New food'));
      await tester.pump();
      await tester.tap(find.text('New food'), warnIfMissed: false);
      await settle(tester, rounds: 6);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Name'), 'Chicken & Rice');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Calories'), '650');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Protein g'), '45');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Carbs g'), '70');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Fat g'), '15');
      await tester.tap(find.text('SAVE TO MY LIBRARY'));
      await settle(tester, rounds: 6);

      // Servings confirmation dialog, then it lands in today's ledger.
      expect(find.text('Log it'), findsOneWidget);
      await tester.tap(find.text('Log it'));
      await settle(tester);

      expect(find.text('Chicken & Rice'), findsOneWidget);
      expect(find.text('650'), findsWidgets); // logged calories on dashboard
    });
  });

  testWidgets(
      'workout: split, weekday plan, guided play with preset sets and rest',
      (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);
      await completeOnboarding(tester);

      await tester.tap(find.text('Lift'));
      await settle(tester, rounds: 6);

      // Create a split.
      await tester.tap(find.text('NEW SPLIT'));
      await settle(tester, rounds: 6);
      await tester.enterText(
          find.widgetWithText(TextField, 'Name (e.g. PPL, Bro split)'),
          'PPL');
      await tester.tap(find.text('Create'));
      await settle(tester, rounds: 6);
      expect(find.text('PPL'), findsWidgets);

      // Plan one exercise on today's weekday: 3 preset sets.
      await tester.tap(find.text('+ ADD EXERCISE'));
      await settle(tester, rounds: 6);
      await tester.enterText(
          find.widgetWithText(TextField, 'Exercise name (e.g. Bench Press)'),
          'Bench Press');
      // Fill target weight/reps for the 3 default set rows.
      final kgFields = find.widgetWithText(TextField, 'kg');
      final repFields = find.widgetWithText(TextField, 'reps');
      await tester.enterText(kgFields.at(0), '20');
      await tester.enterText(repFields.at(0), '14');
      await tester.enterText(kgFields.at(1), '25');
      await tester.enterText(repFields.at(1), '10');
      await tester.enterText(kgFields.at(2), '35');
      await tester.enterText(repFields.at(2), '8');
      await tester.tap(find.text('SAVE EXERCISE'));
      await settle(tester);

      // The plan is visible on the day card.
      expect(find.textContaining('20kg×14'), findsOneWidget);

      // Play: guided session, set 1 pre-filled with 20 x 14.
      await tester.tap(find.text('▶ START WORKOUT'));
      await settle(tester);
      expect(find.text('SET 1 OF 3'), findsOneWidget);
      expect(find.text('planned 20 kg × 14'.toUpperCase()), findsOneWidget);
      expect(
          (tester.widget(find.widgetWithText(TextField, 'kg'))
                  as TextField)
              .controller!
              .text,
          '20');

      // Log set 1 as planned.
      await tester.tap(find.text('✓ DONE — LOG SET'));
      await settle(tester, rounds: 6);

      // Rest countdown with extend/shorten, and next-set preview.
      expect(find.text('REST'), findsOneWidget);
      expect(find.text('+15S'), findsOneWidget);
      expect(find.text('-15S'), findsOneWidget);
      expect(find.textContaining('set 2 of 3'), findsOneWidget);

      // Start next set early; set 2 pre-fills 25 x 10.
      await tester.tap(find.text('▶ START NEXT SET'));
      await settle(tester, rounds: 6);
      expect(find.text('SET 2 OF 3'), findsOneWidget);
      expect(
          (tester.widget(find.widgetWithText(TextField, 'kg'))
                  as TextField)
              .controller!
              .text,
          '25');

      // Adjust the actual weight (25 -> 27.5) and log it.
      await tester.enterText(
          find.widgetWithText(TextField, 'kg'), '27.5');
      await tester.tap(find.text('✓ DONE — LOG SET'));
      await settle(tester, rounds: 6);
      await tester.tap(find.text('▶ START NEXT SET'));
      await settle(tester, rounds: 6);
      expect(find.text('SET 3 OF 3'), findsOneWidget);
      await tester.tap(find.text('✓ DONE — LOG SET'));
      await settle(tester);

      // Last set of last exercise -> workout complete summary.
      expect(find.text('WORKOUT COMPLETE'), findsOneWidget);
      expect(find.text('3'), findsWidgets); // sets logged

      // Sets are locked at the database layer.
      Object? err;
      try {
        await db.db.update('set_logs', {'weight_kg': 999});
      } catch (e) {
        err = e;
      }
      expect(err, isNotNull);

      await tester.tap(find.text('DONE'));
      await settle(tester, rounds: 6);
      expect(find.text('▶ START WORKOUT'), findsOneWidget);
    });
  });

  testWidgets('PR save shows celebration and lands in the Hall of Fame',
      (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);
      await completeOnboarding(tester);

      await tester.tap(find.text('PRs'));
      await settle(tester, rounds: 6);
      await tester.tap(find.text('CLAIM YOUR FIRST PR'));
      await settle(tester, rounds: 6);

      await tester.enterText(
          find.widgetWithText(TextField, 'Exercise'), 'Deadlift');
      await tester.enterText(find.widgetWithText(TextField, 'Weight'), '180');
      await tester.tap(find.text('STAMP IT'));
      await settle(tester, rounds: 6);

      // Celebratory moment on save.
      expect(find.text('* * * NEW RECORD * * *'), findsOneWidget);
      expect(find.text('180 KG'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('TAP TO CONTINUE'));
      await settle(tester);

      // Scoreboard: rank #1, exercise, weight.
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Deadlift'), findsOneWidget);
      expect(find.text('180'), findsOneWidget);
    });
  });

  testWidgets('monthly graph renders with stats row', (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);
      await completeOnboarding(tester);

      await tester.tap(find.text('Month'));
      await settle(tester);

      // Signature screen: stats and the missed-days legend.
      expect(find.text('DAYS LOGGED'), findsOneWidget);
      expect(find.text('MISSED'), findsOneWidget);
      expect(find.text('MISSED — BELOW THE LINE'), findsOneWidget);
    });
  });

  testWidgets('dark mode toggle re-skins without changing structure',
      (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);
      await completeOnboarding(tester);

      await tester.tap(find.text('More'));
      await settle(tester, rounds: 6);
      await tester.tap(find.text('Scoreboard (dark)'));
      await settle(tester);

      final ctx = tester.element(find.text('MORE'));
      expect(Theme.of(ctx).brightness, Brightness.dark);
      // Backup nudge is present (no export has ever been made).
      expect(find.textContaining('backup'), findsWidgets);
      // Same structure: the same tiles are still there.
      expect(find.text('Targets'), findsOneWidget);
      expect(find.text('Gym reminders'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Storage'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Storage'), findsOneWidget);
    });
  });

  testWidgets('tally streak marks appear on the daily view', (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);
      await completeOnboarding(tester);
      expect(find.byType(TallyMarks), findsOneWidget);
    });
  });
}
