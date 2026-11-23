import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/screens/wardrobe_item_detail_screen.dart';
import 'package:flutter_app/screens/wardrobe_screen.dart';

import 'fixtures.dart';

/// Long press starts the catalog's selection mode; how many are picked decides
/// whether edit is offered at all.
void main() {
  Future<void> pumpCatalog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: WardrobeScreen(items: wardrobeFixture)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('long press previews one garment with edit and delete', (
    WidgetTester tester,
  ) async {
    await pumpCatalog(tester);

    await tester.longPress(find.text('Silk Blouse'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('preview-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-delete')), findsOneWidget);

    // Staying in selection mode keeps the single pick and its edit action.
    await tester.tap(find.text('Pilih item lain'));
    await tester.pumpAndSettle();

    expect(find.text('1 dipilih'), findsOneWidget);
    expect(find.byKey(const ValueKey('selection-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('selection-delete')), findsOneWidget);
  });

  testWidgets('two selected garments offer delete only', (
    WidgetTester tester,
  ) async {
    await pumpCatalog(tester);

    await tester.longPress(find.text('Silk Blouse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih item lain'));
    await tester.pumpAndSettle();

    // A tap while selecting adds to the selection instead of opening detail.
    await tester.scrollUntilVisible(
      find.text('Straight Leg Jeans'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // The last drag only lands after a frame: without this the tile is still
    // 130 px below the viewport when the tap fires.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Straight Leg Jeans'));
    await tester.pumpAndSettle();

    // The bar sits in the header, which is off-screen after the scroll, and
    // finders skip offstage widgets by default.
    expect(find.text('2 dipilih', skipOffstage: false), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selection-edit'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('selection-delete'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(WardrobeItemDetailScreen), findsNothing);

    // Tapping the same tile drops it again, and edit comes back.
    await tester.scrollUntilVisible(
      find.text('Straight Leg Jeans'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // The last drag only lands after a frame: without this the tile is still
    // 130 px below the viewport when the tap fires.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Straight Leg Jeans'));
    await tester.pumpAndSettle();

    expect(find.text('1 dipilih', skipOffstage: false), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selection-edit'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('dismissing the preview drops the pick it made', (
    WidgetTester tester,
  ) async {
    await pumpCatalog(tester);

    await tester.longPress(find.text('Silk Blouse'));
    await tester.pumpAndSettle();
    // Tapping the scrim closes the sheet without choosing an action; the pick
    // it made on the way in must not survive.
    await tester.tapAt(const Offset(210, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('preview-edit')), findsNothing);
    expect(find.textContaining('dipilih'), findsNothing);
    expect(find.byKey(const ValueKey('selection-delete')), findsNothing);
  });

  testWidgets('cancelling the selection returns to the plain catalog', (
    WidgetTester tester,
  ) async {
    await pumpCatalog(tester);

    await tester.longPress(find.text('Silk Blouse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih item lain'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Batalkan pilihan'));
    await tester.pumpAndSettle();

    expect(find.text('1 dipilih'), findsNothing);
    expect(find.byKey(const ValueKey('selection-edit')), findsNothing);

    // With nothing selected a tap leaves for the detail page again.
    await tester.tap(find.text('Silk Blouse'));
    await tester.pumpAndSettle();
    expect(find.byType(WardrobeItemDetailScreen), findsOneWidget);
  });
}
