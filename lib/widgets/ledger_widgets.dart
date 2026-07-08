import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rubber-stamp style CTA: dashed border, slight rotation, all-caps.
/// Big touch target by default — this app is used mid-set with sweaty hands.
class StampButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final double rotation; // radians, subtle
  const StampButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.rotation = -0.012,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    final color = onPressed == null
        ? c.inkFaint
        : primary
            ? c.accent
            : c.ink;
    return Transform.rotate(
      angle: rotation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: CustomPaint(
            painter: _DashedBorderPainter(color: color),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              alignment: Alignment.center,
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: monoFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: 1.5,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    const dash = 7.0, gap = 5.0;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(6));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(
            metric.extractPath(dist, math.min(dist + dash, metric.length)),
            paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

/// Chunky-bordered card, the ledger's basic surface.
class LedgerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  const LedgerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor ?? c.ink, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Page background texture: faint ruled-paper lines in light mode, subtle
/// CRT scanlines in dark mode. Same structure, re-skinned.
class LedgerBackground extends StatelessWidget {
  final Widget child;
  const LedgerBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return CustomPaint(
      painter: _RuledPaperPainter(
        lineColor: c.rule,
        spacing: context.isDark ? 4 : 28,
        opacity: context.isDark ? 0.35 : 0.55,
      ),
      child: child,
    );
  }
}

class _RuledPaperPainter extends CustomPainter {
  final Color lineColor;
  final double spacing;
  final double opacity;
  _RuledPaperPainter(
      {required this.lineColor, required this.spacing, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: opacity)
      ..strokeWidth = 1;
    for (var y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RuledPaperPainter old) =>
      old.lineColor != lineColor || old.spacing != spacing;
}

/// Streak counter drawn as tally marks — groups of five (four verticals and
/// a diagonal strike).
class TallyMarks extends StatelessWidget {
  final int count;
  final double height;
  const TallyMarks({super.key, required this.count, this.height = 26});

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    final groups = count ~/ 5;
    final rest = count % 5;
    final width = groups * (4 * 7.0 + 14) + rest * 7.0 + 4;
    return CustomPaint(
      size: Size(math.max(width, 8), height),
      painter: _TallyPainter(
          groups: groups, rest: rest, color: c.accent, height: height),
    );
  }
}

class _TallyPainter extends CustomPainter {
  final int groups;
  final int rest;
  final Color color;
  final double height;
  _TallyPainter(
      {required this.groups,
      required this.rest,
      required this.color,
      required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    var x = 2.0;
    for (var g = 0; g < groups; g++) {
      for (var i = 0; i < 4; i++) {
        canvas.drawLine(Offset(x, 3), Offset(x - 1, height - 3), paint);
        x += 7;
      }
      canvas.drawLine(
          Offset(x - 30, height - 5), Offset(x + 1, 5), paint); // strike
      x += 14;
    }
    for (var i = 0; i < rest; i++) {
      canvas.drawLine(Offset(x, 3), Offset(x - 1, height - 3), paint);
      x += 7;
    }
  }

  @override
  bool shouldRepaint(_TallyPainter old) =>
      old.groups != groups || old.rest != rest || old.color != color;
}

/// Big scoreboard number in the pixel display face — for the "high score"
/// reward moments (monthly graph, PRs, streaks).
class PixelNumber extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  const PixelNumber(this.text, {super.key, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Text(
      text,
      style: TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        height: 0.9,
        color: color ?? c.accent,
        shadows: context.isDark
            ? [Shadow(color: (color ?? c.accent).withValues(alpha: 0.55), blurRadius: 12)]
            : null,
      ),
    );
  }
}

/// Small mono label, e.g. column headers and timestamps.
class MonoLabel extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  const MonoLabel(this.text, {super.key, this.size = 12, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.ledger;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: monoFont,
        fontSize: size,
        letterSpacing: 1.2,
        color: color ?? c.inkFaint,
      ),
    );
  }
}
