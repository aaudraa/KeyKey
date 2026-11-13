import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_done_mark.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/features/backup/application/backup_reminder.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/presentation/backup_section.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ayarların en üstündeki yedek kartı: son yedeğin ne zaman alındığı ve
/// tek dokunuşla yedek alma.
class BackupStatusCard extends ConsumerStatefulWidget {
  const new({super.key});

  /// Atan kartın katmanı (testler için) ve en büyük ölçeği (madde 4.5).
  static const Key pulseKey = ValueKey('kk-backup-pulse');
  static const double pulseScale = 1.03;

  @override
  ConsumerState<BackupStatusCard> createState() => _BackupStatusCardState();
}

class _BackupStatusCardState extends ConsumerState<BackupStatusCard>
    with SingleTickerProviderStateMixin {
  bool _busy = false;

  /// Yedek kaydedildi: düğmede onay işareti çizilir (madde 4.6).
  bool _done = false;

  /// Yedek eskiyse ayarlara her girişte bir kez atış (madde 4.5); kartlar
  /// girişlerini bitirince başlar.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: KkMotion.enter + KkMotion.emphasis,
  );
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible && _isStale()) {
      if (!MediaQuery.disableAnimationsOf(context)) _pulse.forward(from: 0);
    }
    _visible = visible;
  }

  bool _isStale() {
    final last = ref.read(settingsControllerProvider)?.lastBackupAt;
    if (last == null) return true;
    final now = ref.read(backupClockProvider)();
    return now.difference(last) >= BackupReminderRule.staleAfter;
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _backUp() async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    var saved = false;
    try {
      saved = await backUpVault(context, ref);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _done = saved;
        });
      }
    }
  }

  double get _pulseScale {
    if (!_pulse.isAnimating) return 1;
    final start =
        KkMotion.enter.inMicroseconds / _pulse.duration!.inMicroseconds;
    final t = ((_pulse.value - start) / (1 - start)).clamp(0.0, 1.0);
    return 1 + (BackupStatusCard.pulseScale - 1) * math.sin(t * math.pi);
  }

  /// Son yedekten bu yana geçen takvim günü. Saat dilimi kayması ve yaz
  /// saati sonucu değiştirmesin diye günler UTC tarih olarak sayılır.
  static int _daysSince(DateTime last, DateTime now) {
    DateTime day(DateTime t) {
      final local = t.toLocal();
      return DateTime.utc(local.year, local.month, local.day);
    }

    final days = day(now).difference(day(last)).inDays;
    return days < 0 ? 0 : days;
  }

  void _showHelp(AppLocalizations l10n) => unawaited(
    showKkSheet<void>(
      context,
      builder: (context) => KkSheetContent(
        title: l10n.backupCreate,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.otpClose),
          ),
        ],
        child: Text(l10n.backupHelp),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final last = ref.watch(settingsControllerProvider)?.lastBackupAt;
    final String status;
    if (last == null) {
      status = l10n.backupStatusNever;
    } else {
      final days = _daysSince(last, ref.watch(backupClockProvider)());
      status = days == 0 ? l10n.backupStatusToday : l10n.backupStatusDays(days);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: KeyedSubtree(
        key: BackupStatusCard.pulseKey,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) =>
              Transform.scale(scale: _pulseScale, child: child),
          child: GlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(26)),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
            child: Row(
              children: [
                KkIconBox(
                  icon: last == null
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_done_rounded,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.settingsMoreInfo,
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showHelp(l10n),
                ),
                FilledButton(
                  style: kkNeutralButtonStyle(context),
                  onPressed: _busy ? null : () => unawaited(_backUp()),
                  child: _done
                      ? KkDoneMark(
                          semanticLabel: l10n.backupStatusAction,
                          size: 20,
                          onDone: () {
                            if (mounted) setState(() => _done = false);
                          },
                        )
                      : _busy
                      ? Semantics(
                          label: l10n.backupStatusAction,
                          child: const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Text(l10n.backupStatusAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
