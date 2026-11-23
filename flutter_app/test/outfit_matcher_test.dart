import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_app/logic/outfit_matcher.dart';
import 'package:flutter_app/models/wardrobe.dart';

import 'fixtures.dart';

import 'package:flutter_app/screens/outfit_builder_screen.dart';
import 'package:flutter_app/screens/wardrobe_item_detail_screen.dart';
import 'package:flutter_app/state/outfit_store.dart';

const _top = WardrobeItem(
  id: 'test-kaos',
  name: 'Kaos',
  category: 'Tops',
  color: Color(0xFF3B5A80),
  colorName: 'Biru',
  formality: 3,
  occasions: ['Kasual'],
  imagePath: 'assets/images/kaos.jpg',
);

const _otherTop = WardrobeItem(
  id: 'test-kemeja',
  name: 'Kemeja',
  category: 'Tops',
  color: Color(0xFFF2EDE3),
  formality: 3,
  imagePath: 'assets/images/kemeja.jpg',
);

const _bottoms = WardrobeItem(
  id: 'test-celana',
  name: 'Celana',
  category: 'Bottoms',
  color: Color(0xFF8B5E3C),
  formality: 3,
  occasions: ['Kasual'],
  imagePath: 'assets/images/celana.jpg',
);

const _accessory = WardrobeItem(
  id: 'test-jam',
  name: 'Jam',
  category: 'Accessories',
  color: Color(0xFFC9A227),
  formality: 3,
  imagePath: 'assets/images/jam.jpg',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('harmonyOf', () {
    test('reads the wheel: analog, triadic, complementary, clash', () {
      Color hue(double h) => HSVColor.fromAHSV(1, h, 0.7, 0.7).toColor();
      expect(harmonyOf(hue(0), hue(20)), ColorHarmony.analog);
      expect(harmonyOf(hue(0), hue(120)), ColorHarmony.triadic);
      expect(harmonyOf(hue(0), hue(180)), ColorHarmony.komplementer);
      expect(harmonyOf(hue(0), hue(60)), ColorHarmony.kontras);
    });

    test('greyscale is neutral against any hue', () {
      expect(isNeutral(Colors.white), isTrue);
      expect(harmonyOf(Colors.white, Colors.red), ColorHarmony.netral);
    });
  });

  group('canPair', () {
    test('same slot never pairs, layers stack', () {
      expect(canPair(_top, _otherTop), isFalse);
      expect(canPair(_top, _bottoms), isTrue);
      expect(canPair(_accessory, _accessory), isTrue);
    });
  });

  group('recommendMatches', () {
    test('drops same-category items and sorts by score', () {
      final out = recommendMatches(_top, [
        _top,
        _otherTop,
        _bottoms,
        _accessory,
      ]);
      expect(out.map((m) => m.item.name), isNot(contains('Kaos')));
      expect(out.map((m) => m.item.name), isNot(contains('Kemeja')));
      expect(
        out.first.score,
        greaterThanOrEqualTo(out.last.score),
        reason: 'sorted descending',
      );
      expect(out.first.reasons, isNotEmpty);
    });

    test('a shared occasion and close formality raise the score', () {
      final onOccasion = recommendMatches(_top, [_bottoms]).single;
      final offOccasion = recommendMatches(_top, [
        const WardrobeItem(
          id: 'test-sepatu-formal',
          name: 'Sepatu Formal',
          category: 'Shoes',
          color: Color(0xFF8B5E3C),
          formality: 5,
          occasions: ['Formal'],
          imagePath: 'assets/images/sepatu.jpg',
        ),
      ]).single;
      expect(onOccasion.score, greaterThan(offOccasion.score));
    });
  });

  test('outfitFor keeps one best partner per slot', () {
    final out = outfitFor(_top, [_top, _otherTop, _bottoms, _accessory]);
    expect(out.map((m) => m.item.category).toSet(), {'Bottoms', 'Accessories'});
  });

  group('outfitScore', () {
    test('formality includes pair consistency and target occasion fit', () {
      const casualTop = WardrobeItem(
        id: 'casual-top',
        name: 'Kaos',
        category: 'Tops',
        formality: 1,
        imagePath: '',
      );
      const casualBottom = WardrobeItem(
        id: 'casual-bottom',
        name: 'Celana Santai',
        category: 'Bottoms',
        formality: 2,
        imagePath: '',
      );
      const formalTop = WardrobeItem(
        id: 'formal-top',
        name: 'Kemeja',
        category: 'Tops',
        formality: 4,
        imagePath: '',
      );
      const formalBottom = WardrobeItem(
        id: 'formal-bottom',
        name: 'Celana Formal',
        category: 'Bottoms',
        formality: 5,
        imagePath: '',
      );

      final casualPair = pairSubscores(
        casualTop,
        casualBottom,
        occasion: 'Formal',
      ).formality;
      final formalPair = pairSubscores(
        formalTop,
        formalBottom,
        occasion: 'Formal',
      ).formality;

      expect(casualPair, closeTo(0.5, 0.001));
      expect(formalPair, closeTo(0.875, 0.001));
      expect(casualPair, lessThan(formalPair));
    });

    test('uses item ids rather than names for duplicate detection', () {
      final sameId = WardrobeItem(
        id: _top.id,
        name: 'Nama berbeda',
        category: 'Bottoms',
        imagePath: '',
      );
      final sameName = WardrobeItem(
        id: 'item-with-distinct-id',
        name: _top.name,
        category: 'Bottoms',
        imagePath: '',
      );

      expect(pairSubscores(_top, sameId).color, 0);
      expect(pairSubscores(_top, sameName).color, greaterThan(0));
    });

    test('uses occasion-specific weights for pair scoring', () {
      final formal = pairScore(_top, _bottoms, occasion: 'Formal');
      final casual = pairScore(_top, _bottoms, occasion: 'Kasual');
      expect(formal, inInclusiveRange(0, 1));
      expect(casual, inInclusiveRange(0, 1));
      expect(formal, isNot(casual));
    });

    test('averages pairs and drops to 0 on a slot clash', () {
      final clash = outfitScore([_top, _otherTop]);
      expect(clash, 0, reason: 'two tops never pair');

      final good = outfitScore([_top, _bottoms, _accessory]);
      expect(good, greaterThan(clash));
      expect(good, lessThanOrEqualTo(1));
    });

    test('a single item scores 0', () {
      expect(outfitScore([_top]), 0);
    });

    test('weakestPair names the clashing pair', () {
      final weak = weakestPair([_top, _otherTop, _bottoms])!;
      expect({weak.a.name, weak.b.name}, {'Kaos', 'Kemeja'});
      expect(weak.score, 0);
    });
  });

  group('improveOutfit', () {
    test('stays silent when the set already meets the threshold', () {
      final set = [_top, _bottoms, _accessory];
      expect(outfitScore(set), greaterThan(0));
      expect(
        improveOutfit(set, [_top, _bottoms, _accessory], threshold: 0.1),
        isEmpty,
      );
    });

    test('proposes a swap that lifts the score past the threshold', () {
      final set = [_top, _otherTop, _bottoms];
      final swaps = improveOutfit(set, wardrobeFixture, threshold: 0.9);
      expect(swaps, isNotEmpty);

      final best = swaps.first;
      expect(best.newScore, greaterThan(outfitScore(set)));

      final applied = [...set]..[best.index] = best.to;
      expect(outfitScore(applied), best.newScore);
      expect(
        applied.map((i) => i.name).toSet(),
        hasLength(applied.length),
        reason: 'never duplicates an item already in the set',
      );
    });
  });

  group('savedOutfits store', () {
    setUp(() => savedOutfits.value = []);

    test('adds, edits in place, and deletes', () async {
      // Ids must exist in the catalog: SavedOutfit.itemsOf resolves against it.
      final ids = ['seed-silk-blouse', 'seed-straight-leg-jeans'];
      await saveOutfit(
        SavedOutfit(id: 'a', name: 'Kantor', itemIds: ids, threshold: 0.8),
      );
      expect(savedOutfits.value, hasLength(1));

      await saveOutfit(
        SavedOutfit(
          id: 'a',
          name: 'Kantor Senin',
          itemIds: ids,
          threshold: 0.9,
        ),
      );
      expect(
        savedOutfits.value,
        hasLength(1),
        reason: 'same id edits in place',
      );
      expect(savedOutfits.value.single.name, 'Kantor Senin');
      expect(savedOutfits.value.single.itemsOf(wardrobeFixture), hasLength(2));

      await deleteOutfit('a');
      expect(savedOutfits.value, isEmpty);
    });
  });

  testWidgets('builder shows the score and its improvement suggestions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Two tops in one set: guaranteed clash, so the score sits under 95%.
    const ids = [
      'seed-silk-blouse',
      'seed-linen-shirt',
      'seed-straight-leg-jeans',
    ];
    final set = [
      for (final id in ids) ...wardrobeFixture.where((i) => i.id == id),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: OutfitBuilderScreen(
          existing: SavedOutfit(
            id: 'x',
            name: 'Uji',
            itemIds: ids,
            threshold: 0.95,
          ),
          catalog: wardrobeFixture,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Kombinasi'), findsOneWidget);
    expect(find.text('Target Keserasian'), findsOneWidget);
    expect(
      find.text('Minimal skor kecocokan warna, formalitas, dan acara.'),
      findsOneWidget,
    );
    expect(find.text('Pilih pakaian utama'), findsOneWidget);
    expect(find.text('Harmoni warna'), findsNothing);
    expect(find.text('${(outfitScore(set) * 100).round()}%'), findsWidgets);

    final recommendButton = find.text('Buat Kombinasi');
    await tester.ensureVisible(recommendButton);
    await tester.tap(recommendButton);
    await tester.pumpAndSettle();
    expect(find.text('Hasil rekomendasi'), findsNothing);
    expect(find.text('Hasil Kombinasi'), findsOneWidget);
    expect(find.text('Buat Kombinasi'), findsOneWidget);
    expect(find.textContaining('Warna'), findsWidgets);
    expect(find.textContaining('Formalitas'), findsWidgets);
    expect(find.textContaining('Acara'), findsWidgets);
  });

  testWidgets('builder asks for a name before saving an edited combination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final existing = SavedOutfit(
      id: 'rename-dialog-test',
      name: 'Nama lama',
      itemIds: const ['test-kaos', 'test-celana'],
      threshold: 0.5,
    );
    savedOutfits.value = [existing];
    addTearDown(() => savedOutfits.value = []);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OutfitBuilderScreen(
                    existing: existing,
                    catalog: const [_top, _bottoms],
                  ),
                ),
              ),
              child: const Text('Open builder'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open builder'));
    await tester.pumpAndSettle();

    final saveButton = find.text('Simpan Perubahan');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Batal'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText ==
                'Nama kombinasi, mis. Kuliah Senin' &&
            widget.autofocus,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(savedOutfits.value.single.name, 'Nama lama');

    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kuliah Senin');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(savedOutfits.value.single.id, existing.id);
    expect(savedOutfits.value.single.name, 'Kuliah Senin');

    await tester.tap(find.text('Open builder'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(savedOutfits.value.single.name, 'Kombinasi Baru');
  });

  testWidgets('builder recommends a complete outfit from one selected top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: OutfitBuilderScreen(catalog: wardrobeFixture)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pilih pakaian utama'), findsOneWidget);
    expect(
      find.text(
        'Untuk sementara, nama hanya menjadi label saat kombinasi disimpan.',
      ),
      findsNothing,
    );
    expect(find.text('Isi otomatis'), findsNothing);
    expect(find.text('Isi Otomatis'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('recommendation-top')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silk Blouse'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Smart Casual'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'Smart-Casual',
    );
    final createButton = find.text('Buat Kombinasi');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('Hasil rekomendasi'), findsNothing);
    expect(find.text('Bottoms'), findsWidgets);
    expect(find.text('Outerwear'), findsWidgets);
    expect(find.text('Shoes'), findsWidgets);
    expect(find.text('Accessories'), findsWidgets);
    expect(find.byIcon(Icons.refresh), findsWidgets);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    final anchorBottom = find.byKey(const ValueKey('recommendation-bottom'));
    expect(
      find.descendant(of: anchorBottom, matching: find.text('Pilih item')),
      findsOneWidget,
      reason: 'recommended Bottoms must not become the input anchor',
    );
    expect(
      find.text('Straight Leg Jeans').evaluate().isNotEmpty ||
          find.text('Pleated Midi Skirt').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('Beige Trench'), findsWidgets);

    final resultBottom = find.byKey(const ValueKey('result-Bottoms'));
    await tester.tap(
      find.descendant(
        of: resultBottom,
        matching: find.byTooltip('Hapus dari kombinasi'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: resultBottom,
        matching: find.text('Slot dikosongkan'),
      ),
      findsOneWidget,
    );
    final refreshBottom = find.descendant(
      of: resultBottom,
      matching: find.byTooltip('Refresh Bottoms'),
    );
    expect(refreshBottom, findsOneWidget);
    await tester.tap(refreshBottom);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: resultBottom,
        matching: find.text('Slot dikosongkan'),
      ),
      findsNothing,
    );
  });

  testWidgets('empty result slots show neutral unavailable state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: OutfitBuilderScreen(catalog: [wardrobeFixture.first])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('recommendation-top')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silk Blouse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat Kombinasi'));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada item yg cocok'), findsNWidgets(4));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    final emptyBottom = find.byKey(const ValueKey('result-Bottoms'));
    expect(
      find.descendant(of: emptyBottom, matching: find.byIcon(Icons.add)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: emptyBottom,
        matching: find.byIcon(Icons.checkroom_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Pastikan atasan (Tops) dan bawahan (Bottoms) terisi sebelum menyimpan',
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty result slots stay inactive until combinations are made', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: OutfitBuilderScreen(catalog: [_top, _bottoms])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('recommendation-top')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recommendation-bottom')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Celana'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Pastikan atasan (Tops) dan bawahan (Bottoms) terisi sebelum menyimpan',
      ),
      findsNothing,
    );
    expect(find.text('Belum dibuat'), findsNWidgets(3));
    expect(find.byIcon(Icons.refresh), findsNothing);
    for (final slot in ['Outerwear', 'Shoes', 'Accessories']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('result-$slot')),
          matching: find.text('Belum dibuat'),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('detail page lists the matched pieces', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WardrobeItemDetailScreen(
          item: wardrobeFixture.first,
          catalog: wardrobeFixture,
        ),
      ),
    );

    expect(find.text('Cocok Dipadukan Dengan'), findsOneWidget);
    expect(find.text(wardrobeFixture.first.name), findsWidgets);

    final expected = outfitFor(wardrobeFixture.first, wardrobeFixture);
    expect(expected, isNotEmpty);
    for (final match in expected) {
      expect(find.text(match.item.name), findsOneWidget);
    }
    expect(find.textContaining('%'), findsNWidgets(expected.length));
  });
}
