import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/core/vault/password_policy.dart';
import 'package:keykey/features/vault/application/password_report.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Zayıf ve tekrar eden parolalar. Parolaların kendisi gösterilmez; kayda
/// dokununca düzenleme ekranı açılır.
class PasswordReportScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final report = ref.watch(passwordReportProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitle)),
      body: report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.reportInfo),
                ),
                if (report.isClean)
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(l10n.reportClean),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l10n.reportOpenHint),
                  ),
                  if (report.weak.isNotEmpty) ...[
                    _SectionHeader(l10n.reportWeakTitle(report.weak.length)),
                    for (final weak in report.weak)
                      _LoginTile(
                        item: weak.item,
                        detail: weak.strength == PasswordStrength.tooShort
                            ? l10n.reportWeakShort
                            : l10n.reportWeakGuessable,
                      ),
                  ],
                  if (report.reused.isNotEmpty) ...[
                    _SectionHeader(
                      l10n.reportReusedTitle(report.reused.length),
                    ),
                    for (final group in report.reused)
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Text(
                                l10n.reportReusedGroup(group.length),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            for (final item in group) _LoginTile(item: item),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _LoginTile extends StatelessWidget {
  const new({required this.item, this.detail});

  final LoginItem item;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final username = item.content.username;
    final subtitle = [?detail, if (username.isNotEmpty) username].join(' · ');
    return ListTile(
      title: Text(item.content.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => context.push(AppRoutes.vaultItemEdit(loginIdHex(item.id))),
    );
  }
}
