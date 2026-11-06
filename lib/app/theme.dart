import 'package:flutter/material.dart';

/// Identidad visual de Koma: "tinta y papel". Negro cálido, crema y un rojo
/// bermellón tipo sello (hanko) como único acento fuerte.
@immutable
class KomaColors extends ThemeExtension<KomaColors> {
  const KomaColors({
    required this.ink,
    required this.surface,
    required this.surfaceHigh,
    required this.paper,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.line,
    required this.glass,
  });

  final Color ink; // fondo
  final Color surface;
  final Color surfaceHigh;
  final Color paper; // texto principal
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color line;
  final Color glass;

  static const dark = KomaColors(
    ink: Color(0xFF0E0D10),
    surface: Color(0xFF17151B),
    surfaceHigh: Color(0xFF221F29),
    paper: Color(0xFFF4EFE6),
    muted: Color(0xFF9D96A3),
    accent: Color(0xFFFF5233),
    accentSoft: Color(0x33FF5233),
    line: Color(0x1FFFFFFF),
    glass: Color(0xB3181620),
  );

  static const light = KomaColors(
    ink: Color(0xFFF6F1E7),
    surface: Color(0xFFFFFCF6),
    surfaceHigh: Color(0xFFEDE6D8),
    paper: Color(0xFF1B191F),
    muted: Color(0xFF6F6872),
    accent: Color(0xFFE63E1E),
    accentSoft: Color(0x24E63E1E),
    line: Color(0x1F000000),
    glass: Color(0xCCFFFCF6),
  );

  /// Pares de degradado para portadas sin imagen (elegidos por hash del título).
  static const coverGradients = <List<Color>>[
    [Color(0xFFFF7A4D), Color(0xFF8B2C5B)],
    [Color(0xFF4D8BFF), Color(0xFF2B1F6B)],
    [Color(0xFF3DD6A8), Color(0xFF14566B)],
    [Color(0xFFFFC857), Color(0xFFB4372E)],
    [Color(0xFFB57BFF), Color(0xFF3A1F6B)],
    [Color(0xFFFF6B9D), Color(0xFF5A2A6B)],
  ];

  @override
  KomaColors copyWith() => this;

  @override
  KomaColors lerp(KomaColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return KomaColors(
      ink: l(ink, other.ink),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      paper: l(paper, other.paper),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      line: l(line, other.line),
      glass: l(glass, other.glass),
    );
  }
}

extension KomaTheme on BuildContext {
  KomaColors get koma => Theme.of(this).extension<KomaColors>()!;
}

/// Estilos de texto con peso real en fuentes variables (eje wght).
TextStyle _display(
  double size,
  double weight,
  Color color, {
  double height = 1.1,
  double letter = -0.5,
}) => TextStyle(
  fontFamily: 'Fraunces',
  fontSize: size,
  fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
  fontVariations: [
    FontVariation('wght', weight),
    const FontVariation('opsz', 72),
    const FontVariation('SOFT', 60),
  ],
  height: height,
  letterSpacing: letter,
  color: color,
);

TextStyle _body(
  double size,
  double weight,
  Color color, {
  double height = 1.45,
  double letter = 0,
}) => TextStyle(
  fontFamily: 'Manrope',
  fontSize: size,
  fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
  fontVariations: [FontVariation('wght', weight)],
  height: height,
  letterSpacing: letter,
  color: color,
);

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? KomaColors.dark : KomaColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(
        primary: c.accent,
        onPrimary: Colors.white,
        surface: c.ink,
        onSurface: c.paper,
        surfaceContainerHighest: c.surfaceHigh,
        outline: c.line,
      );

  final text = TextTheme(
    displayLarge: _display(44, 800, c.paper),
    headlineLarge: _display(34, 760, c.paper),
    headlineMedium: _display(28, 720, c.paper),
    headlineSmall: _display(24, 700, c.paper),
    titleLarge: _display(20, 680, c.paper, letter: -0.2),
    titleMedium: _body(16, 700, c.paper),
    titleSmall: _body(14, 700, c.paper),
    bodyLarge: _body(16, 500, c.paper),
    bodyMedium: _body(14, 500, c.paper),
    bodySmall: _body(12, 500, c.muted),
    labelLarge: _body(14, 700, c.paper, letter: 0.2),
    labelMedium: _body(12, 700, c.muted, letter: 0.3),
    labelSmall: _body(11, 700, c.muted, letter: 0.6),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.ink,
    canvasColor: c.ink,
    textTheme: text,
    fontFamily: 'Manrope',
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: c.paper,
      titleTextStyle: text.titleLarge,
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surfaceHigh,
      contentTextStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
