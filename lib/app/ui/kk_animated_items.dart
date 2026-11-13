import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_entrance.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_pressable.dart';

/// Kayıt listesinin hareketli dilimi (madde 2.3, 2.7, 3.6). Liste her
/// değiştiğinde eski ve yeni anahtarları karşılaştırır:
///
/// * çıkan öğe sola [slide] dp kayar, solar, yüksekliği sıfıra iner
///   ([KkMotion.base], [KkMotion.exit]); alttakiler yukarı kayar;
/// * giren öğe solarak ve yüksekliği açılarak gelir ([KkMotion.standard]);
/// * sıra değiştiyse (sıralama) ya da değişiklik [maxAnimatedChanges]'ten
///   çoksa liste baştan kurulur, kartlar giriş hareketiyle yeni yerlerinde
///   belirir. Gerçek kaydırma her kartın yerini ölçmeyi gerektirir, 1000
///   kayıtta pahalı (plan Görev 10, benim kararım).
///
/// Yalnızca ekranda görünen öğeler kurulur. Her öğenin altında [gap] boşluk
/// vardır; çıkan öğeyle birlikte o da kapanır.
class KkAnimatedItems<T> extends StatefulWidget {
  const new({
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    super.key,
  });

  /// Öğeler arası boşluk.
  static const double gap = 8;

  /// Çıkan öğenin sola kayma payı.
  static const double slide = 24;

  /// Bundan çok ekleme ve çıkarmada liste baştan kurulur: yüzlerce ayrı
  /// animasyon aynı anda koşmasın.
  static const int maxAnimatedChanges = 60;

  final List<T> items;

  /// Öğenin kalıcı kimliği (ör. kayıt kimliği).
  final Object Function(T item) keyOf;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  @override
  State<KkAnimatedItems<T>> createState() => _KkAnimatedItemsState<T>();
}

class _KkAnimatedItemsState<T> extends State<KkAnimatedItems<T>> {
  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();
  final _skip = KkEntranceSkip();
  late List<Object> _keys;

  @override
  void initState() {
    super.initState();
    _keys = _keysOf(widget.items);
  }

  List<Object> _keysOf(List<T> items) => [
    for (final item in items) widget.keyOf(item),
  ];

  @override
  void didUpdateWidget(KkAnimatedItems<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKeys = _keys;
    final newKeys = _keysOf(widget.items);
    _keys = newKeys;
    if (listEquals(oldKeys, newKeys)) return;

    final oldSet = oldKeys.toSet();
    final newSet = newKeys.toSet();
    final keptOld = [
      for (final key in oldKeys)
        if (newSet.contains(key)) key,
    ];
    final keptNew = [
      for (final key in newKeys)
        if (oldSet.contains(key)) key,
    ];
    final changes =
        (oldKeys.length - keptOld.length) + (newKeys.length - keptNew.length);
    final list = _listKey.currentState;
    if (list == null ||
        !listEquals(keptOld, keptNew) ||
        changes > KkAnimatedItems.maxAnimatedChanges) {
      // Liste baştan kurulur; bu karede kurulan kartlar giriş hareketini
      // atlayıp hemen görünür, liste bir an bile boşalmaz.
      _listKey = GlobalKey();
      _skip.active = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _skip.active = false);
      return;
    }

    final duration = KkMotion.of(context, KkMotion.base);
    final oldItems = oldWidget.items;
    // Sondan başa: önceki çıkarmalar sonraki sıra numaralarını bozmasın.
    for (var i = oldKeys.length - 1; i >= 0; i--) {
      if (newSet.contains(oldKeys[i])) continue;
      final item = oldItems[i];
      list.removeItem(
        i,
        (context, animation) => _Slot(
          presence: animation.drive(
            CurveTween(curve: const FlippedCurve(KkMotion.exit)),
          ),
          removing: true,
          child: widget.itemBuilder(context, item, i),
        ),
        duration: duration,
      );
    }
    // Kalanların sırası aynı; yeni öğeler kendi yerlerine baştan sona girer.
    for (var j = 0; j < newKeys.length; j++) {
      if (!oldSet.contains(newKeys[j])) {
        list.insertItem(j, duration: duration);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KkEntranceSkipScope(
      skip: _skip,
      child: SliverAnimatedList(
        key: _listKey,
        initialItemCount: widget.items.length,
        itemBuilder: (context, index, animation) => _Slot(
          presence: animation.drive(CurveTween(curve: KkMotion.standard)),
          removing: false,
          child: widget.itemBuilder(context, widget.items[index], index),
        ),
      ),
    );
  }
}

/// Bir öğenin yeri. Duran, giren ve çıkan öğe aynı ağaç yapısındadır; çıkan
/// öğe kendi öğesinin durumunu (ör. giriş hareketi oynandı) korur.
class _Slot extends StatelessWidget {
  const new({
    required this.presence,
    required this.removing,
    required this.child,
  });

  /// 1: tam yerinde, 0: yok.
  final Animation<double> presence;
  final bool removing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: presence,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: presence,
        child: AnimatedBuilder(
          animation: presence,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              removing ? -KkAnimatedItems.slide * (1 - presence.value) : 0,
              0,
            ),
            child: child,
          ),
          child: IgnorePointer(
            ignoring: removing,
            child: Padding(
              padding: const EdgeInsets.only(bottom: KkAnimatedItems.gap),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ekranın kayıt listesi: [KkAnimatedItems] ile hareketli kartlar, her kart
/// [KkEntrance] ile giriş yapar. Liste boşsa [empty] ortada solarak ve 8 dp
/// yükselerek belirir (madde 3.6).
class KkItemsView<T> extends StatelessWidget {
  const new({
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    required this.empty,
    required this.padding,
    this.header,
    this.controller,
    super.key,
  });

  final ScrollController? controller;

  /// Listenin üstünde onunla birlikte kayan baş kısım (büyük başlık, arama
  /// kutusu, süzgeçler).
  final Widget? header;

  final List<T> items;
  final Object Function(T item) keyOf;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Liste boşken gösterilen yazı.
  final Widget empty;

  /// Listenin kenar boşlukları; alttaki, son kartın boşluğu dahil.
  final EdgeInsets padding;

  /// Boş durumun yükselme payı.
  static const double emptyRise = 8;

  @override
  Widget build(BuildContext context) {
    return KkEntranceScope(
      child: CustomScrollView(
        controller: controller,
        slivers: [
          if (header != null) SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: padding.copyWith(
              bottom: math.max(0, padding.bottom - KkAnimatedItems.gap),
            ),
            sliver: KkAnimatedItems<T>(
              items: items,
              keyOf: keyOf,
              itemBuilder: (context, item, index) => KkEntrance(
                index: index,
                child: itemBuilder(context, item, index),
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: KkRiseIn(rise: emptyRise, fade: true, child: empty),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
