import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_entrance.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// "+" kutusunda seçilebilecek ekleme yolları.
enum AddChoice { password, otpScan, otpImage, otpManual, otpImport }

/// Menüdeki "+" ile açılan kutu: arkada kararan ve bulanan ekran, menünün
/// hemen üstünde cam kutu. Önce "Parola mı, 2FA kodu mu" diye sorar; "2FA
/// kodu" aynı kutuda dört yola geçer.
class AddPanel extends StatefulWidget {
  const new({
    required this.passwordEnabled,
    required this.otpEnabled,
    required this.onChosen,
    required this.onDismiss,
    this.animation = kAlwaysCompleteAnimation,
    super.key,
  });

  /// Kayıtlar yüklenmeden "Parola" etkisizdir.
  final bool passwordEnabled;

  /// Hesaplar yüklenmeden "2FA kodu" etkisizdir.
  final bool otpEnabled;
  final ValueChanged<AddChoice> onChosen;
  final VoidCallback onDismiss;

  /// Açılış (0 → 1) ve kapanış (1 → 0) ilerlemesi.
  final Animation<double> animation;

  @override
  State<AddPanel> createState() => _AddPanelState();
}

class _AddPanelState extends State<AddPanel> {
  bool _otpPage = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final glass = KkGlass.of(context);
    final theme = Theme.of(context);
    final animation = widget.animation;
    final bottom =
        GlassNavBar.height +
        GlassNavBar.bottomGap +
        MediaQuery.paddingOf(context).bottom +
        12;
    final spring = CurvedAnimation(
      parent: animation,
      curve: KkMotion.spring,
      reverseCurve: Curves.easeInCubic,
    );

    final rows = _otpPage
        ? [
            _PanelRow(
              icon: Icons.qr_code_scanner_rounded,
              title: l10n.otpAddScan,
              onTap: () => widget.onChosen(AddChoice.otpScan),
            ),
            _PanelRow(
              icon: Icons.image_outlined,
              title: l10n.otpAddImage,
              onTap: () => widget.onChosen(AddChoice.otpImage),
            ),
            _PanelRow(
              icon: Icons.keyboard_outlined,
              title: l10n.otpAddManual,
              onTap: () => widget.onChosen(AddChoice.otpManual),
            ),
            _PanelRow(
              icon: Icons.download_rounded,
              title: l10n.otpAddImport,
              onTap: () => widget.onChosen(AddChoice.otpImport),
            ),
          ]
        : [
            _PanelRow(
              icon: Icons.key_rounded,
              title: l10n.addPassword,
              hint: l10n.addPasswordHint,
              onTap: widget.passwordEnabled
                  ? () => widget.onChosen(AddChoice.password)
                  : null,
            ),
            _PanelRow(
              icon: Icons.shield_outlined,
              title: l10n.addOtp,
              hint: l10n.addOtpHint,
              trailing: Icons.chevron_right_rounded,
              onTap: widget.otpEnabled
                  ? () => setState(() => _otpPage = true)
                  : null,
            ),
          ];

    final header = Padding(
      padding: EdgeInsetsDirectional.only(
        start: _otpPage ? 4 : 18,
        end: 18,
        top: _otpPage ? 4 : 14,
        bottom: 4,
      ),
      child: Row(
        children: [
          if (_otpPage)
            IconButton(
              tooltip: l10n.addBack,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _otpPage = false),
            ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                _otpPage ? l10n.addOtp : l10n.addTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final box = GlassSurface(
      blur: true,
      strong: true,
      borderRadius: const BorderRadius.all(Radius.circular(26)),
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedSize(
          duration: KkMotion.of(context, KkMotion.base),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: KkMotion.of(context, KkMotion.base),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KkEntranceScope(
              key: ValueKey(_otpPage),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    for (var i = 0; i < rows.length; i++)
                      KkEntrance(index: i, child: rows[i]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: FadeTransition(
                opacity: animation,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: ColoredBox(color: glass.scrim),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(spring),
              alignment: Alignment.bottomRight,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: l10n.addTitle,
                child: box,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.hint,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                KkIconBox(icon: icon, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hint != null)
                        Text(
                          hint!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Icon(trailing, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
