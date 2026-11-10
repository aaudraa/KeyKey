import 'package:flutter/material.dart';

/// KeyKey'in renkleri. Değerler ve kontrast oranları
/// `resources/docs/tasarim-yenileme.md` belgesinde.
abstract final class KkColors {
  /// Simgedeki parlak turuncu. Krem zeminde yazı için yeterli kontrast
  /// vermediği için yalnızca simgede ve büyük yüzeylerde kullanılır.
  static const brandOrange = Color(0xFFF26B1D);

  static const cream = Color(0xFFF6F1E7);
  static const card = Color(0xFFFFFDF8);
  static const cardBorder = Color(0xFFE7DFCF);
  static const field = Color(0xFFECE5D6);
  static const ink = Color(0xFF2B2A28);
  static const inkMuted = Color(0xFF696356);
  static const accent = Color(0xFFB4470F);

  static const darkCream = Color(0xFF1C1A17);
  static const darkCard = Color(0xFF24211D);
  static const darkCardBorder = Color(0xFF34302A);
  static const darkField = Color(0xFF2A2723);
  static const darkInk = Color(0xFFEFE8DA);
  static const darkInkMuted = Color(0xFF9B9384);
  static const darkAccent = Color(0xFFFF8A4C);
}

abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? KkColors.darkCream : KkColors.cream;
    final card = isDark ? KkColors.darkCard : KkColors.card;
    final border = isDark ? KkColors.darkCardBorder : KkColors.cardBorder;
    final field = isDark ? KkColors.darkField : KkColors.field;
    final ink = isDark ? KkColors.darkInk : KkColors.ink;
    final muted = isDark ? KkColors.darkInkMuted : KkColors.inkMuted;
    final accent = isDark ? KkColors.darkAccent : KkColors.accent;
    final onAccent = isDark ? KkColors.darkCream : Colors.white;
    final error = isDark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: isDark
          ? const Color(0xFF4A2A17)
          : const Color(0xFFFBE3D3),
      onPrimaryContainer: ink,
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: field,
      onSecondaryContainer: ink,
      error: error,
      onError: isDark ? KkColors.darkCream : Colors.white,
      surface: card,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: card,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: field,
      surfaceContainerHighest: field,
      outline: muted,
      outlineVariant: border,
      inverseSurface: ink,
      onInverseSurface: background,
      inversePrimary: isDark ? KkColors.accent : KkColors.darkAccent,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    const cardRadius = BorderRadius.all(Radius.circular(14));
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        border: const OutlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide(color: error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: border),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        modalBackgroundColor: background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(iconColor: muted),
    );
  }
}
