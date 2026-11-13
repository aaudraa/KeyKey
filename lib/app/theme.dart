import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';

/// KeyKey'in renkleri. Değerler ve kontrast oranları
/// `resources/docs/tasarim-cam-plani.md` belgesinde. Zemin tek renk olmadığı
/// için her yazı rengi zeminin en kötü noktasına göre seçildi.
abstract final class KkColors {
  /// Simgedeki parlak turuncu. Yazı için yeterli kontrast vermediği için
  /// yalnızca simgede kullanılır.
  static const brandOrange = Color(0xFFF26B1D);

  static const ground = Color(0xFFF3EEF4);
  static const ink = Color(0xFF1B1A1F);
  static const inkMuted = Color(0xFF55515E);
  static const accentText = Color(0xFF9A3A08);
  static const accent = Color(0xFFC2470C);
  static const error = Color(0xFFA1201A);
  static const surface = Color(0xFFF9F6FA);
  static const blobsLight = [
    Color(0xFFFF9A5A),
    Color(0xFFB48CFF),
    Color(0xFFFF6FA3),
  ];

  static const darkGround = Color(0xFF0C0B10);
  static const darkInk = Color(0xFFF5F2F8);
  static const darkInkMuted = Color(0xFFC4BFCD);
  static const darkAccentText = Color(0xFFFFA873);
  static const darkAccent = Color(0xFFFF9457);
  static const darkError = Color(0xFFFFB4AB);
  static const darkSurface = Color(0xFF1F1E23);
  static const blobsDark = [
    Color(0xFFF26B1D),
    Color(0xFF6B3BFF),
    Color(0xFFE0336E),
  ];

  /// Ana düğmenin turuncu geçişi; üstünde koyu yazı ([onCta]) durur, beyaz
  /// yazı kontrastı tutmuyor.
  static const ctaStart = Color(0xFFFF9A52);
  static const ctaEnd = Color(0xFFEC5512);
  static const onCta = Color(0xFF1B1A1F);

  /// Baş harf kutularının renkleri; hepsinde beyaz harf en az 5:1 okunur.
  static const avatarPalette = [
    Color(0xFFC2410C),
    Color(0xFF2563EB),
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFFBE185D),
    Color(0xFF15803D),
    Color(0xFFB45309),
    Color(0xFF475569),
    Color(0xFFB91C1C),
    Color(0xFF0E7490),
  ];
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
    final accentText = isDark ? KkColors.darkAccentText : KkColors.accentText;
    final accent = isDark ? KkColors.darkAccent : KkColors.accent;
    final error = isDark ? KkColors.darkError : KkColors.error;
    final onAccentText = isDark ? KkColors.ink : Colors.white;

    final glass = KkGlass(
      fill: Colors.white.withValues(alpha: isDark ? 0.08 : 0.50),
      fillStrong: Colors.white.withValues(alpha: isDark ? 0.12 : 0.62),
      navFill: isDark
          ? KkColors.darkGround.withValues(alpha: 0.30)
          : Colors.white.withValues(alpha: 0.26),
      capsule: Colors.white.withValues(alpha: isDark ? 0.16 : 0.72),
      border: Colors.white.withValues(alpha: isDark ? 0.17 : 0.70),
      highlight: Colors.white.withValues(alpha: isDark ? 0.28 : 0.95),
      shadow: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
      scrim: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
      accent: accent,
      accentContainer: accent.withValues(alpha: isDark ? 0.18 : 0.12),
      onCta: KkColors.onCta,
      ctaGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [KkColors.ctaStart, KkColors.ctaEnd],
      ),
      ground: ground,
      blobs: isDark ? KkColors.blobsDark : KkColors.blobsLight,
      blobAlpha: isDark ? 0.38 : 0.36,
    );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accentText,
      onPrimary: onAccentText,
      primaryContainer: glass.accentContainer,
      onPrimaryContainer: ink,
      secondary: accentText,
      onSecondary: onAccentText,
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
      inversePrimary: isDark ? KkColors.accentText : KkColors.darkAccentText,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    const cardRadius = BorderRadius.all(Radius.circular(22));
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
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? ink.withValues(alpha: 0.38)
                : KkColors.onCta,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? ink.withValues(alpha: 0.38)
                : KkColors.onCta,
          ),
          overlayColor: WidgetStatePropertyAll(
            KkColors.onCta.withValues(alpha: 0.10),
          ),
          textStyle: WidgetStatePropertyAll(
            base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          backgroundBuilder: (context, states, child) => DecoratedBox(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              gradient: states.contains(WidgetState.disabled)
                  ? null
                  : glass.ctaGradient,
              color: states.contains(WidgetState.disabled) ? glass.fill : null,
            ),
            child: child,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          backgroundColor: glass.fill,
          side: BorderSide(color: glass.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glass.fill,
        selectedColor: glass.capsule,
        side: BorderSide(color: glass.border),
        shape: const StadiumBorder(),
        checkmarkColor: accent,
        labelStyle: TextStyle(color: ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? surface : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : glass.fill,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : muted,
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
        actionTextColor: accentText,
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
