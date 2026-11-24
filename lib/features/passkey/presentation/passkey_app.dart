import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_load_failed.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/autofill/presentation/autofill_sheet_frame.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/lock_screen.dart';
import 'package:keykey/features/onboarding/application/terms_controller.dart';
import 'package:keykey/features/passkey/application/passkey_bridge.dart';
import 'package:keykey/features/passkey/application/passkey_service.dart';
import 'package:keykey/features/passkey/domain/passkey_plan.dart';
import 'package:keykey/features/passkey/domain/webauthn.dart';
import 'package:keykey/features/settings/application/theme_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// İş bitti; pencere kapanırken kilit ekranı yeniden çizilmesin.
final passkeyDoneProvider = NotifierProvider<PasskeyDone, bool>(
  PasskeyDone.new,
);

class PasskeyDone extends Notifier<bool> {
  @override
  bool build() => false;

  void markDone() => state = true;
}

/// Pencereyi kapatır: kasayı kilitler ve sonucu Android'e verir.
void finishPasskey(
  WidgetRef ref,
  Future<void> Function(PasskeyBridge bridge) result,
) {
  ref.read(passkeyDoneProvider.notifier).markDone();
  ref.read(vaultControllerProvider.notifier).lock();
  unawaited(result(ref.read(passkeyBridgeProvider)));
}

/// Passkey penceresinin uygulaması. Ana uygulamadan ayrı bir Flutter
/// motorunda, `passkeyMain` giriş noktasıyla çalışır.
class PasskeyApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'KeyKey',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PasskeyHome(),
    );
  }
}

/// İsteğe ve kasanın durumuna göre doğru içeriği seçer.
class PasskeyHome extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(passkeyDoneProvider)) return const SizedBox.shrink();
    void cancel() => finishPasskey(ref, (bridge) => bridge.cancel());
    return ref
        .watch(passkeyPromptProvider)
        .when(
          loading: () => _Loading(onDismiss: cancel),
          error: (error, _) {
            final kind = error is PasskeyRequestException
                ? error.kind
                : PasskeyError.invalidRequest;
            return _Message(
              passkeyErrorText(l10n, kind),
              onClose: () => finishPasskey(ref, (bridge) => bridge.fail(kind)),
            );
          },
          data: (prompt) {
            if (prompt == null) {
              return _Message(l10n.passkeyNoRequest, onClose: cancel);
            }
            final status = ref.watch(vaultControllerProvider);
            // Koşullar kabul edilmeden kasa açılmaz; kabul uygulamada yapılır.
            if (status is! VaultNotSetUp && !ref.watch(termsAcceptedProvider)) {
              return _Message(l10n.autofillNeedsTerms, onClose: cancel);
            }
            return switch (status) {
              VaultNotSetUp() => _Message(
                l10n.autofillNoVault,
                onClose: cancel,
              ),
              VaultUnavailable() || VaultRecovering() => _Message(
                l10n.autofillVaultUnavailable,
                onClose: cancel,
              ),
              VaultLocked() => AutofillSheetFrame(
                onDismiss: cancel,
                child: LockScreen(
                  allowRecovery: false,
                  compact: true,
                  subtitle: prompt.isCreate
                      ? l10n.passkeyCreateFor(prompt.rpId)
                      : l10n.passkeySignInFor(prompt.rpId),
                ),
              ),
              VaultOpen() when prompt.isCreate => PasskeyCreateContent(
                prompt: prompt,
              ),
              VaultOpen() => PasskeyGetContent(prompt: prompt),
            };
          },
        );
  }
}

String passkeyErrorText(AppLocalizations l10n, PasskeyError kind) =>
    switch (kind) {
      PasskeyError.invalidRequest => l10n.passkeyInvalid,
      PasskeyError.unsupportedAlgorithm => l10n.passkeyUnsupported,
      PasskeyError.alreadyExists => l10n.passkeyAlreadyExists,
      PasskeyError.rpIdMismatch => l10n.passkeyRpMismatch,
      PasskeyError.tooMany => l10n.passkeyTooMany,
    };

/// Kasa açıkken oluşturma onayı: site, hesap, çağıran, uyarı ve hangi
/// kayda yazılacağı.
class PasskeyCreateContent extends ConsumerStatefulWidget {
  const new({required this.prompt, super.key});

  final PasskeyPrompt prompt;

  @override
  ConsumerState<PasskeyCreateContent> createState() =>
      _PasskeyCreateContentState();
}

class _PasskeyCreateContentState extends ConsumerState<PasskeyCreateContent> {
  /// Seçilen kayıt; `null` yeni kayıt. İlk çizimde ilk aday seçilir.
  LoginItem? _target;
  bool _chosen = false;
  bool _busy = false;
  PasskeyError? _error;

  Future<void> _create({required bool verified}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final snack = kkSnackFor(context);
    setState(() => _busy = true);
    final String response;
    try {
      response = await ref
          .read(passkeyServiceProvider)
          .create(prompt: widget.prompt, target: _target, bindApp: verified);
    } on PasskeyRequestException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.kind;
        });
      }
      return;
    } on VaultLockedException {
      // Kasa kilitlendi; kilit ekranı yeniden açılıyor.
      if (mounted) setState(() => _busy = false);
      return;
    } on Exception {
      snack(l10n.loginSaveFailed);
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    finishPasskey(ref, (bridge) => bridge.finishCreate(response));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void cancel() => finishPasskey(ref, (bridge) => bridge.cancel());
    final error = _error;
    if (error != null) {
      return _Message(
        passkeyErrorText(l10n, error),
        onClose: () => finishPasskey(ref, (bridge) => bridge.fail(error)),
      );
    }
    final candidates = ref.watch(passkeyCandidatesProvider);
    final verified = ref.watch(passkeyAppVerifiedProvider);
    if (candidates case AsyncError(error: final PasskeyRequestException e)) {
      return _Message(
        passkeyErrorText(l10n, e.kind),
        onClose: () => finishPasskey(ref, (bridge) => bridge.fail(e.kind)),
      );
    }
    if (candidates is AsyncError) {
      return _LoadFailed(onDismiss: cancel);
    }
    final targets = candidates.value?.targets;
    final isVerified = verified.value;
    if (targets == null || isVerified == null) {
      return _Loading(onDismiss: cancel);
    }
    if (!_chosen) {
      _target = targets.firstOrNull;
      _chosen = true;
    }
    final prompt = widget.prompt;
    final options = prompt.creation!;
    final account = options.userName.isNotEmpty
        ? options.userName
        : options.userDisplayName;
    return AutofillSheetFrame(
      onDismiss: cancel,
      child: _Panel(
        icon: Icons.key_rounded,
        title: l10n.passkeyCreateTitle,
        lines: [
          l10n.passkeySite(prompt.rpId),
          if (account.isNotEmpty) l10n.passkeyAccount(account),
          callerLine(l10n, prompt),
        ],
        warning: isVerified
            ? null
            : l10n.passkeyUnverifiedApp(callerName(prompt), prompt.rpId),
        extra: targets.isEmpty
            ? null
            : _TargetChoice(
                targets: targets,
                selected: _target,
                onSelect: (item) => setState(() => _target = item),
              ),
        onCancel: cancel,
        confirmLabel: l10n.passkeyCreateTitle,
        onConfirm: _busy ? null : () => _create(verified: isVerified),
      ),
    );
  }
}

/// Kasa açılınca girişte: o sitenin passkey'leri için yanıtları hazırlar
/// ve hesapları sisteme verir. Doğrulanmamış uygulamada önce uyarır.
class PasskeyGetContent extends ConsumerStatefulWidget {
  const new({required this.prompt, super.key});

  final PasskeyPrompt prompt;

  @override
  ConsumerState<PasskeyGetContent> createState() => _PasskeyGetContentState();
}

class _PasskeyGetContentState extends ConsumerState<PasskeyGetContent> {
  bool _confirmed = false;
  bool _started = false;

  Future<void> _sign(PasskeyCandidates candidates) async {
    final List<PasskeyAssertion> assertions;
    try {
      assertions = await ref
          .read(passkeyServiceProvider)
          .assertions(prompt: widget.prompt, passkeys: candidates.passkeys);
    } on Exception {
      if (mounted) {
        finishPasskey(
          ref,
          (bridge) => bridge.fail(PasskeyError.invalidRequest),
        );
      }
      return;
    }
    if (!mounted) return;
    finishPasskey(ref, (bridge) => bridge.finishGet(assertions));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void cancel() => finishPasskey(ref, (bridge) => bridge.cancel());
    final candidates = ref.watch(passkeyCandidatesProvider);
    final verified = ref.watch(passkeyAppVerifiedProvider);
    if (candidates is AsyncError) return _LoadFailed(onDismiss: cancel);
    final found = candidates.value;
    final isVerified = verified.value;
    if (found == null || isVerified == null) {
      return _Loading(onDismiss: cancel);
    }
    final prompt = widget.prompt;
    if (found.passkeys.isEmpty) {
      return _Message(
        l10n.passkeyNone(prompt.rpId),
        onClose: () => finishPasskey(ref, (bridge) => bridge.finishGet([])),
      );
    }
    if (!isVerified && !_confirmed) {
      return AutofillSheetFrame(
        onDismiss: cancel,
        child: _Panel(
          icon: Icons.warning_amber_rounded,
          title: l10n.passkeyWarnTitle,
          lines: [l10n.passkeySite(prompt.rpId), callerLine(l10n, prompt)],
          warning: l10n.passkeyUnverifiedApp(callerName(prompt), prompt.rpId),
          onCancel: cancel,
          confirmLabel: l10n.passkeyContinue,
          onConfirm: () => setState(() => _confirmed = true),
        ),
      );
    }
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_sign(found));
      });
    }
    return _Loading(onDismiss: cancel);
  }
}

/// Çağıranın kullanıcıya gösterilen adı.
String callerName(PasskeyPrompt prompt) =>
    prompt.caller.appLabel ?? prompt.caller.packageName;

/// "Chrome içinde" ya da "Örnek uygulaması için".
String callerLine(AppLocalizations l10n, PasskeyPrompt prompt) =>
    prompt.caller.isBrowser
    ? l10n.passkeyInBrowser(callerName(prompt))
    : l10n.passkeyForApp(callerName(prompt));

class _TargetChoice extends StatelessWidget {
  const new({
    required this.targets,
    required this.selected,
    required this.onSelect,
  });

  final List<LoginItem> targets;
  final LoginItem? selected;
  final ValueChanged<LoginItem?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget option(LoginItem? item, String title, String? subtitle) {
      final isSelected = identical(item, selected);
      return Semantics(
        selected: isSelected,
        inMutuallyExclusiveGroup: true,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: isSelected ? theme.colorScheme.primary : null,
          ),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          onTap: () => onSelect(item),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(l10n.passkeySaveTo, style: theme.textTheme.titleSmall),
        for (final item in targets)
          option(
            item,
            item.content.name.isEmpty ? '—' : item.content.name,
            item.content.username.isEmpty ? null : item.content.username,
          ),
        option(null, l10n.passkeyNewLogin, null),
      ],
    );
  }
}

/// Başlık, bilgi satırları, varsa uyarı ve iki düğmeli içerik.
class _Panel extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.lines,
    required this.onCancel,
    required this.confirmLabel,
    required this.onConfirm,
    this.warning,
    this.extra,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final String? warning;
  final Widget? extra;
  final VoidCallback onCancel;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warning = this.warning;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(line),
                  ),
                if (warning != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(warning)),
                    ],
                  ),
                ],
                ?extra,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(onPressed: onCancel, child: Text(l10n.autofillCancel)),
              FilledButton(onPressed: onConfirm, child: Text(confirmLabel)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const new({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => AutofillSheetFrame(
    onDismiss: onDismiss,
    child: const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _LoadFailed extends ConsumerWidget {
  const new({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AutofillSheetFrame(
    onDismiss: onDismiss,
    child: KkLoadFailed(
      onRetry: () =>
          unawaited(ref.read(loginsControllerProvider.notifier).retry()),
    ),
  );
}

class _Message extends StatelessWidget {
  const new(this.text, {required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AutofillSheetFrame(
      onDismiss: onClose,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onClose, child: Text(l10n.autofillClose)),
          ],
        ),
      ),
    );
  }
}
