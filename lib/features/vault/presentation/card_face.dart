import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kart ayrıntısının başındaki kart görünümü: marka, gizli numara, kart
/// sahibi ve son kullanma. Numaranın yalnızca son grubu görünür.
class CardFace extends StatelessWidget {
  const new({required this.content, required this.now, super.key});

  final CardContent content;

  /// Süresi geçmiş mi diye bakılan an.
  final DateTime now;

  /// Kredi kartı oranı (ISO/IEC 7810 ID-1).
  static const double aspectRatio = 85.60 / 53.98;

  static const double maxWidth = 380;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final expiry = content.expiry;
    final expired = expiry != null && expiry.isExpiredAt(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            // Geniş ekranda da cüzdandaki kart boyunda kalır.
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: GlassSurface(
                strong: true,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.credit_card_rounded, color: muted),
                        const Spacer(),
                        if (content.cardBrand case final brand?)
                          Text(
                            brand.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (content.number.isNotEmpty)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          maskCardNumber(content.number),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            content.cardholder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (expiry != null)
                          Text(
                            expiry.format(),
                            style: theme.textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expired)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.cardExpired,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
