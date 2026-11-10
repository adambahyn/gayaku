import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/models/wardrobe.dart';
import 'package:flutter_app/state/wardrobe_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wardrobe_cache');
  });

  tearDown(() async {
    await closeWardrobeStore();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  WardrobeItem item(String id, {String name = 'Kaos'}) => WardrobeItem(
    id: id,
    name: name,
    category: 'Tops',
    imagePath: '/cutouts/$id.png',
  );

  test('mirroring the backend drops rows the server no longer has', () async {
    await initWardrobeStore(
      factory: databaseFactoryFfi,
      path: '${temp.path}/wardrobe.db',
    );
    // A stale seeded row plus one that really exists on the server.
    await addWardrobeItem(item('seed-1', name: 'Kemeja Lama'));
    await addWardrobeItem(item('real-1'));

    await mirrorWardrobeCache([item('real-1')]);

    expect(wardrobeItems.value.map((i) => i.id), ['real-1']);
  });

  test('mirroring an empty account empties the cache', () async {
    await initWardrobeStore(
      factory: databaseFactoryFfi,
      path: '${temp.path}/wardrobe.db',
    );
    await addWardrobeItem(item('seed-1'));

    await mirrorWardrobeCache(const []);

    expect(wardrobeItems.value, isEmpty);
  });

  test('a cached row keeps its local image path and colour', () async {
    await initWardrobeStore(
      factory: databaseFactoryFfi,
      path: '${temp.path}/wardrobe.db',
    );
    await addWardrobeItem(
      WardrobeItem(
        id: 'real-1',
        name: 'Kaos',
        category: 'Tops',
        imagePath: '/cutouts/real-1.png',
        color: const Color(0xFF102030),
      ),
    );

    await mirrorWardrobeCache([item('real-1')]);

    final row = wardrobeItems.value.single;
    expect(row.imagePath, '/cutouts/real-1.png');
    expect(row.color, const Color(0xFF102030));
  });
}