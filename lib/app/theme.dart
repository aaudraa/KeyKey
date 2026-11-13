import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_metrics.dart';

/// KeyKey'in renkleri: siyah, beyaz ve gri; turuncu yalnızca dört yerde.
/// Değerler ve kontrast oranları `resources/docs/tasarim-siyah-beyaz-plani.md`
/// belgesinde. Zemin tek renk olmadığı için her yazı rengi zeminin en kötü
/// noktasına göre seçildi.
abstract final class KkColors {
  /// Simgedeki ve logodaki turuncu; açık temada dolgu turuncusu da budur.
  static const brandOrange = Color(0xFFF26B1D);

  static const ground = Color(0xFFE6E6E8);
  static const ink = Color(0xFF111111);
  static const inkMuted = Color(0xFF525252);
  static const error = Color(0xFFA1201A);
  static const surface = Color(0xFFF7F7F8);

  /// Açık temada ince turuncu çizgi: `brandOrange` zeminde 3:1 tutmuyor.
  static const brandStroke = Color(0xFFC2470C);
  static const blobsLight = [
    Color(0xFFFFFFFF),
    Color(0xFFA9A9AE),
    Color(0xFFFFFFFF),
  ];

  static const darkGround = Color(0xFF000000);
  static const darkInk = Color(0xFFF4F4F4);
  static const darkInkMuted = Color(0xFFADADAD);
  static const darkError = Color(0xFFFFB4AB);
  static const darkSurface = Color(0xFF161617);
  static const darkBrand = Color(0xFFFF8A4C);
  static const blobsDark = [
    Color(0xFF5A5A5E),
    Color(0xFF3A3A3E),
    Color(0xFF4A4A4E),
  ];

  /// Turuncunun üstündeki yazı ve simge (iki temada).
  static const onBrand = Color(0xFF1A0D05);
}

abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ground = isDark ? KkColors.darkGround : KkColors.ground;
    final surface = isDark ? KkColors.darkSurface : KkColors.surface;
    final ink = isDark ? KkColors.darkInk : KkColors.ink;
    final muted = isDark ? KkColors.darkInkMuted : KkColors.inkMuted;
    final error = isDark ? KkColors.darkError : KkColors.error;
    final brand = isDark ? KkColors.darkBrand : KkColors.brandOrange;

    final glass = KkGlass(
      fill: Colors.white.withValues(alpha: isDark ? 0.07 : 0.52),
      fillStrong: Colors.white.withValues(alpha: isDark ? 0.12 : 0.62),
      navFill: isDark
          ? KkColors.darkGround.withValues(alpha: 0.30)
          : Colors.white.withValues(alpha: 0.26),
      border: Colors.white.withValues(alpha: isDark ? 0.17 : 0.70),
      highlight: Colors.white.withValues(alpha: isDark ? 0.28 : 0.95),
      shadow: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
      scrim: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
      accent: ink,
      tint: isDark
          ? Colors.white.withValues(alpha: 0.09)
          : Colors.black.withValues(alpha: 0.06),
      brand: brand,
      onBrand: KkColors.onBrand,
      brandStroke: isDark ? KkColors.darkBrand : KkColors.brandStroke,
      ground: ground,
      blobs: isDark ? KkColors.blobsDark : KkColors.blobsLight,
      blobAlpha: isDark ? 0.50 : 0.45,
    );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: ink,
      onPrimary: ground,
      primaryContainer: glass.tint,
      onPrimaryContainer: ink,
      secondary: ink,
      onSecondary: ground,
      tertiary: ink,
      onTertiary: ground,
      secondaryContainer: glass.fill,
      onSecondaryContainer: ink,
      error: error,
      onError: isDark ? KkColors.ink : Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surface,
      outline: muted,
      outlineVariant: glass.border,
      inverseSurface: ink,
      onInverseSurface: ground,
      inversePrimary: isDark ? KkColors.ink : KkColors.darkInk,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    const cardRadius = BorderRadius.all(Radius.circular(KkMetrics.cardRadius));
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(KkMetrics.buttonRadius)),
    );
    final base = ThemeData(brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      extensions: [glass],
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: surface,
      // Android 14+ kenardan geri hareketinde sayfa parmağı izler.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: glass.fill,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: glass.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        filled: true,
        fillColor: glass.fill,
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
          borderSide: BorderSide(color: ink, width: 1.5),
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
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, KkMetrics.buttonHeight),
          ),
          shape: const WidgetStatePropertyAll(buttonShape),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? glass.fill : brand,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? ink.withValues(alpha: 0.38)
                : KkColors.onBrand,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? ink.withValues(alpha: 0.38)
                : KkColors.onBrand,
          ),
          overlayColor: WidgetStatePropertyAll(
            KkColors.onBrand.withValues(alpha: 0.10),
          ),
          textStyle: WidgetStatePropertyAll(
            base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, KkMetrics.buttonHeight),
          shape: buttonShape,
          foregroundColor: ink,
          backgroundColor: glass.fill,
          side: BorderSide(color: glass.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glass.fill,
        selectedColor: glass.tint,
        side: BorderSide(color: glass.border),
        shape: const StadiumBorder(),
        checkmarkColor: ink,
        labelStyle: TextStyle(color: ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ground : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : glass.fill,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : muted,
        ),
      ),
      // Pencerenin camını showKkSheet çizer.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      // showKkSnack kendi camını çizer. Doğrudan gösterilen SnackBar'lar
      // opak yüzeyde kalır ki zeminin üstünde okunsun.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: ink),
        actionTextColor: ink,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          side: BorderSide(color: glass.border),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: glass.border,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(iconColor: muted),
      iconTheme: IconThemeData(color: ink),
    );
  }
}
