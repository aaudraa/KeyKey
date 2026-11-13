import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/last_saved.dart';

void main() {
  testWidgets('okunmayan son kayıt kısa süre sonra unutulur', (tester) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            ref.watch(lastSavedProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    widgetRef.read(lastSavedProvider.notifier).mark(savedLoginKey('ab'));
    await tester.pump();
    expect(widgetRef.read(lastSavedProvider), savedLoginKey('ab'));
    await tester.pump(LastSaved.window ~/ 2);
    expect(widgetRef.read(lastSavedProvider), savedLoginKey('ab'));
    await tester.pump(LastSaved.window);
    // Ekran dışında kalan kart dakikalar sonra kaydırılınca parlamasın.
    expect(widgetRef.read(lastSavedProvider), isNull);
  });

  testWidgets('yeni kayıt süreyi baştan başlatır', (tester) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            ref.watch(lastSavedProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    final notifier = widgetRef.read(lastSavedProvider.notifier)
      ..mark(savedLoginKey('ab'));
    await tester.pump(LastSaved.window * 0.75);
    notifier.mark(savedOtpKey('cd'));
    await tester.pump(LastSaved.window * 0.75);
    expect(widgetRef.read(lastSavedProvider), savedOtpKey('cd'));
    await tester.pump(LastSaved.window);
    expect(widgetRef.read(lastSavedProvider), isNull);
  });
}
