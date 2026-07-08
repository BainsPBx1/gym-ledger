import 'package:flutter/material.dart';

/// Retro "gym ledger meets arcade scoreboard" palette.
///
/// Light mode: cream ledger paper, ink-dark text, ruled-paper lines, chunky
/// borders, rubber-stamp CTAs. Dark mode: near-black CRT, glowing amber,
/// rust-red for missed/negative states, olive-green secondary accents.
/// Both modes share identical structure — dark is a re-skin, not a redesign.
class LedgerColors extends ThemeExtension<LedgerColors> {
  final Color paper; // page background
  final Color card; // raised surface
  final Color ink; // primary text / borders
  final Color inkFaint; // secondary text
  final Color rule; // ruled-paper / scanline lines
  final Color accent; // stamps, CTAs, highlights (red ink / amber glow)
  final Color negative; // missed days, destructive
  final Color secondary; // olive-green secondary accent
  final Color onAccent;

  const LedgerColors({
    required this.paper,
    required this.card,
    required this.ink,
    required this.inkFaint,
    required this.rule,
    required this.accent,
    required this.negative,
    required this.secondary,
    required this.onAccent,
  });

  static const light = LedgerColors(
    paper: Color(0xFFF6F1E3), // cream ledger paper
    card: Color(0xFFFDFAF1),
    ink: Color(0xFF23201A), // ink-dark
    inkFaint: Color(0xFF6E6759),
    rule: Color(0xFFD9CFB9), // faint ruled lines
    accent: Color(0xFFB3402A), // red stamp ink
    negative: Color(0xFF8F2D16),
    secondary: Color(0xFF5A6337), // olive
    onAccent: Color(0xFFF6F1E3),
  );

  static const dark = LedgerColors(
    paper: Color(0xFF0D0C0A), // near-black CRT
    card: Color(0xFF171512),
    ink: Color(0xFFFFB648), // glowing amber
    inkFaint: Color(0xFF9A7A45),
    rule: Color(0xFF262219),
    accent: Color(0xFFFFB648),
    negative: Color(0xFFC24A28), // rust-red
    secondary: Color(0xFF8A9A5B), // olive-green
    onAccent: Color(0xFF0D0C0A),
  );

  @override
  LedgerColors copyWith({Color? paper}) => this;

  @override
  LedgerColors lerp(LedgerColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return LedgerColors(
      paper: l(paper, other.paper),
      card: l(card, other.card),
      ink: l(ink, other.ink),
      inkFaint: l(inkFaint, other.inkFaint),
      rule: l(rule, other.rule),
      accent: l(accent, other.accent),
      negative: l(negative, other.negative),
      secondary: l(secondary, other.secondary),
      onAccent: l(onAccent, other.onAccent),
    );
  }
}

/// Everyday UI text: clean grotesk. Data/timestamps/stats: monospace.
/// Big reward numbers (monthly graph, PRs, streaks): pixel display face.
const uiFont = 'PlexSans';
const monoFont = 'SpaceMono';
const displayFont = 'VT323';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? LedgerColors.light : LedgerColors.dark;

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: uiFont,
    scaffoldBackgroundColor: c.paper,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.secondary,
      onSecondary: c.paper,
      error: c.negative,
      onError: c.paper,
      surface: c.card,
      onSurface: c.ink,
    ),
  );

  return base.copyWith(
    extensions: [c],
    textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: c.paper,
      foregroundColor: c.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: uiFont,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: c.ink,
        letterSpacing: 0.5,
      ),
    ),
    dividerTheme: DividerThemeData(color: c.rule, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: c.ink, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: c.ink, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: c.accent, width: 3),
      ),
      labelStyle: TextStyle(color: c.inkFaint, fontFamily: monoFont),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(color: c.paper, fontFamily: monoFont),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(c.ink),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.rule),
    ),
  );
}

extension LedgerContext on BuildContext {
  LedgerColors get ledger => Theme.of(this).extension<LedgerColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
