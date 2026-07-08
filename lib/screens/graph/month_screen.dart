import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ledger_widgets.dart';

final _monthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final _monthDaysProvider =
    FutureProvider.family<List<DayAggregate>, DateTime>((ref, month) async {
  ref.watch(mealsVersionProvider);
  ref.watch(workoutsVersionProvider);
  final settings = await ref.watch(settingsProvider.future);
  return ref.watch(statsDaoProvider).daysForMonth(month, settings.targets);
});

/// The app's signature screen: one month of eating and training as a
/// scoreboard. Bars rise with calories logged against target; days with no
/// log at all dip below the center baseline as rust-red negative bars —
/// visibly different from days that were logged but landed off target.
class MonthScreen extends ConsumerWidget {
  const MonthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ledger;
    final month = ref.watch(_monthProvider);
    final daysAsync = ref.watch(_monthDaysProvider(month));
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final atCurrent = !month.isBefore(thisMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('THE MONTH'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 30),
            onPressed: () => ref.read(_monthProvider.notifier).state =
                DateTime(month.year, month.month - 1, 1),
          ),
          SizedBox(
            width: 110,
            child: Center(
              child: MonoLabel(DateFormat('MMM yyyy').format(month), size: 13,
                  color: c.ink),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 30),
            onPressed: atCurrent
                ? null
                : () => ref.read(_monthProvider.notifier).state =
                    DateTime(month.year, month.month + 1, 1),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LedgerBackground(
        child: daysAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (days) {
            final logged = days
                .where((d) => d.status != DayStatus.missed)
                .length;
            final onTarget =
                days.where((d) => d.status == DayStatus.onTarget).length;
            final workouts = days.where((d) => d.workedOut).length;
            final missed =
                days.where((d) => d.status == DayStatus.missed).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(child: _stat(context, '$logged', 'days logged')),
                    Expanded(
                        child: _stat(context, '$onTarget', 'on target',
                            color: c.secondary)),
                    Expanded(child: _stat(context, '$workouts', 'workouts')),
                    Expanded(
                        child: _stat(context, '$missed', 'missed',
                            color: c.negative)),
                  ],
                ),
                const SizedBox(height: 16),
                LedgerCard(
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                  child: SizedBox(
                    height: 300,
                    child: days.isEmpty
                        ? Center(
                            child: MonoLabel('Nothing this month',
                                size: 12, color: c.inkFaint))
                        : CustomPaint(
                            size: Size.infinite,
                            painter: MonthGraphPainter(
                              days: days,
                              colors: c,
                              isDark: context.isDark,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _legend(c.accent, 'on target'),
                    _legend(c.secondary, 'logged, off target'),
                    _legend(c.negative, 'missed — below the line'),
                    _legendDot(c.ink, 'workout day'),
                  ],
                ),
                const SizedBox(height: 20),
                _MacroTotals(days: days),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label,
      {Color? color}) {
    return Column(
      children: [
        PixelNumber(value, size: 42, color: color),
        MonoLabel(label, size: 9),
      ],
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 6),
          MonoLabel(label, size: 10),
        ],
      );

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          MonoLabel(label, size: 10),
        ],
      );
}

class _MacroTotals extends StatelessWidget {
  final List<DayAggregate> days;
  const _MacroTotals({required this.days});

  @override
  Widget build(BuildContext context) {
    final loggedDays = days.where((d) => d.status != DayStatus.missed).toList();
    if (loggedDays.isEmpty) return const SizedBox.shrink();
    final n = loggedDays.length;
    final avgCal =
        loggedDays.fold(0.0, (s, d) => s + d.calories) / n;
    final avgP = loggedDays.fold(0.0, (s, d) => s + d.proteinG) / n;
    final avgC = loggedDays.fold(0.0, (s, d) => s + d.carbsG) / n;
    final avgF = loggedDays.fold(0.0, (s, d) => s + d.fatG) / n;
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MonoLabel('Average on logged days', size: 11),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _avg(context, '${avgCal.round()}', 'kcal'),
              _avg(context, '${avgP.round()}g', 'protein'),
              _avg(context, '${avgC.round()}g', 'carbs'),
              _avg(context, '${avgF.round()}g', 'fat'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avg(BuildContext context, String v, String label) => Column(
        children: [
          PixelNumber(v, size: 30),
          MonoLabel(label, size: 9),
        ],
      );
}

/// The graph itself. Center baseline; positive bars scale with the day's
/// calories relative to 1.3x target; missed days draw a fixed negative bar
/// below the baseline. Workout days get a dot above their bar.
class MonthGraphPainter extends CustomPainter {
  final List<DayAggregate> days;
  final LedgerColors colors;
  final bool isDark;
  MonthGraphPainter(
      {required this.days, required this.colors, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const bottomPad = 18.0; // room for day numbers
    final plotH = size.height - bottomPad;
    final baseline = plotH * 0.72;
    final missedDepth = plotH * 0.16;
    final maxBarH = baseline - 14;

    final daysInMonth =
        DateTime(days.first.day.year, days.first.day.month + 1, 0).day;
    final slot = size.width / daysInMonth;
    final barW = (slot * 0.62).clamp(2.0, 18.0);

    // Peak calories for vertical scale: at least 1.3x of the largest day.
    final maxCal = days.fold(0.0, (m, d) => d.calories > m ? d.calories : m);
    final scaleMax = maxCal <= 0 ? 1.0 : maxCal * 1.15;

    final barPaint = Paint()..style = PaintingStyle.fill;
    final glow = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Baseline rule.
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = colors.ink.withValues(alpha: 0.8)
        ..strokeWidth = 2,
    );

    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    for (final d in days) {
      final i = d.day.day - 1;
      final cx = slot * i + slot / 2;

      if (d.status == DayStatus.missed) {
        // Missed: a bar dipping below the center baseline.
        final rect = Rect.fromLTWH(
            cx - barW / 2, baseline + 2, barW, missedDepth);
        barPaint.color = colors.negative;
        if (isDark) {
          glow.color = colors.negative.withValues(alpha: 0.5);
          canvas.drawRect(rect, glow);
        }
        canvas.drawRect(rect, barPaint);
      } else {
        final h = (d.calories / scaleMax * maxBarH).clamp(3.0, maxBarH);
        final rect =
            Rect.fromLTWH(cx - barW / 2, baseline - h, barW, h);
        final color = d.status == DayStatus.onTarget
            ? colors.accent
            : colors.secondary;
        barPaint.color = color;
        if (isDark) {
          glow.color = color.withValues(alpha: 0.5);
          canvas.drawRect(rect, glow);
        }
        canvas.drawRect(rect, barPaint);
      }

      if (d.workedOut) {
        final topY = d.status == DayStatus.missed
            ? baseline - 8
            : baseline -
                (d.calories / scaleMax * maxBarH).clamp(3.0, maxBarH) -
                8;
        canvas.drawCircle(
            Offset(cx, topY), 2.6, Paint()..color = colors.ink);
      }

      // Day-of-month labels every 5 days.
      if ((i + 1) % 5 == 0 || i == 0) {
        tp.text = TextSpan(
          text: '${i + 1}',
          style: TextStyle(
              fontFamily: monoFont, fontSize: 9, color: colors.inkFaint),
        );
        tp.layout();
        tp.paint(canvas,
            Offset(cx - tp.width / 2, size.height - bottomPad + 4));
      }
    }
  }

  @override
  bool shouldRepaint(MonthGraphPainter old) =>
      old.days != days || old.isDark != isDark;
}
