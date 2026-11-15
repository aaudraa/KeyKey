import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_metrics.dart';

/// KeyKey'in renkleri: açık temada krem, koyu temada gri; turuncu yalnızca
/// dört yerde.
/// Değerler ve kontrast oranları `resources/docs/tasarim-siyah-beyaz-plani.md`
/// belgesinde. Zemin tek renk olmadığı için her yazı rengi zeminin en kötü
/// noktasına göre seçildi.
abstract final class KkColors {
  /// Simgedeki ve logodaki turuncu; açık temada dolgu turuncusu da budur.
  static const brandOrange = Color(0xFFF26B1D);

  /// Açık tema krem: zemin, kart ve yazılar sıcak tonlu (telefon
  /// denemesi 6, kullanıcı Claude uygulamasındaki kremi istedi).
  static const ground = Color(0xFFECE9DF);
  static const ink = Color(0xFF141413);
  static const inkMuted = Color(0xFF57564F);
  static const error = Color(0xFFA1201A);
  static const surface = Color(0xFFFAF9F5);

  /// Açık temada kartların dolu rengi: saf beyaz değil açık krem.
  static const card = Color(0xFFFAF9F5);

  /// Açık temada ince turuncu çizgi: `brandOrange` zeminde 3:1 tutmuyor.
  static const brandStroke = Color(0xFFC2470C);
  static const blobsLight = [
    Color(0xFFFAF9F5),
    Color(0xFFC9C3B1),
    Color(0xFFFAF9F5),
  ];

  /// Koyu temada zemin tam siyah değil, yazı saf beyaz değil, kartlar
  /// zeminden belirgin açık: tam siyah üstünde parlak yazı ve zeminden
  /// zor ayrılan kartlar gözü yoruyor, ekran karışık görünüyordu
  /// (telefon denemesi 6).
  static const darkGround = Color(0xFF121214);
  static const darkInk = Color(0xFFE6E6E8);
  static const darkInkMuted = Color(0xFFA2A2A8);
  static const darkError = Color(0xFFFFB4AB);
  static const darkSurface = Color(0xFF242427);

  /// Koyu temada kartların dolu rengi (telefon denemesi 4: buzlu cam değil).
  static const darkCard = Color(0xFF2E2E32);
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
      fill: isDark ? KkColors.darkCard : KkColors.card,
      fillStrong: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : KkColors.card.withValues(alpha: 0.92),
      navFill: Colors.white.withValues(alpha: isDark ? 0.03 : 0.05),
      // Kartın tepesindeki parlak beyaz şerit ve beyaz çerçeve koyu
      // temada siyahın, açık temada kremin üstünde göze batıyordu
      // (telefon denemesi 6). Açık temada kartı ince sıcak bir çizgi
      // çevreler.
      border: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : KkColors.ink.withValues(alpha: 0.07),
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
      blobAlpha: isDark ? 0.12 : 0.45,
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
      // Etiket çerçeve çizgisine değil, kutunun içine oturur: alanlar cam
      // kartın içinde durduğu için çizgideki etiketin yarısı kesiliyordu
      // (telefon denemesi 5). Odak ve hata alt çizgiyle gösterilir.
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        filled: true,
        fillColor: glass.fill,
        border: const UnderlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide.none,
        ),
        disabledBorder: const UnderlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: cardRadius,
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: UnderlineInputBorder(
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
