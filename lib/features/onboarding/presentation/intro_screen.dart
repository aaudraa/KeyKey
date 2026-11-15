import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_sheet.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/onboarding/presentation/intro_art.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// İlk açılıştaki tanıtım: altı sayfa, kaydırarak ya da "İleri" ile geçilir.
///
/// Kasa yokken açılışta gelir ve kasa oluşturmaya götürür. Kasa açıkken
/// Ayarlar'dan yeniden izlenir; o zaman son düğme "Bitti" olur ve Ayarlar'a
/// döner. Hiçbir şey saklanmaz: kasa kurulunca tanıtım kendiliğinden bir
/// daha gelmez. Tasarım `resources/docs/tanitim.md` belgesinde.
class IntroScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const pageCount = 6;

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _replay => ref.read(vaultControllerProvider) is VaultOpen;

  bool get _last => _page == IntroScreen.pageCount - 1;

  void _finish() {
    if (!_replay) {
      context.go(AppRoutes.setup);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.settings);
    }
  }

  Future<void> _next() => _pages.nextPage(
    duration: KkMotion.of(context, KkMotion.enter),
    curve: KkMotion.standard,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final texts = [
      (l10n.introWelcomeTitle, l10n.introWelcomeBody),
      (l10n.introOfflineTitle, l10n.introOfflineBody),
      (l10n.introTourTitle, l10n.introTourBody),
      (l10n.introAutofillTitle, l10n.introAutofillBody),
      (l10n.introImportTitle, l10n.introImportBody),
      (l10n.introBackupTitle, l10n.introBackupBody),
    ];
    return KkScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(l10n.introSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  for (final (i, (title, body)) in texts.indexed)
                    _IntroPage(
                      art: IntroArt(page: i, active: i == _page),
                      title: title,
                      body: body,
                    ),
                ],
              ),
            ),
            _Dots(
              page: _page,
              label: l10n.introPage(_page + 1, IntroScreen.pageCount),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _last
                  ? FilledButton(
                      onPressed: _finish,
                      child: Text(_replay ? l10n.introDone : l10n.introStart),
                    )
                  : FilledButton(
                      // Turuncu yalnızca son sayfanın düğmesinde.
                      style: kkNeutralButtonStyle(context),
                      onPressed: _next,
                      child: Text(l10n.introNext),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const new({required this.art, required this.title, required this.body});

  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(height: KkMetrics.introArtHeight, child: art),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Sayfa noktaları; seçili olan uzar.
class _Dots extends StatelessWidget {
  const new({required this.page, required this.label});

  final int page;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < IntroScreen.pageCount; i++)
              AnimatedContainer(
                duration: KkMotion.of(context, KkMotion.base),
                curve: KkMotion.standard,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == page ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == page ? ink : ink.withValues(alpha: 0.25),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
