import 'package:flutter/foundation.dart';

import '../models/wardrobe.dart';
import '../services/wardrobe_service.dart';
import 'wardrobe_store.dart';

/// Supabase is the shared wardrobe and `wardrobe.db` is this device's copy.
/// The screens read one `wardrobeItems` notifier, so both sides meet here
/// instead of every screen learning about the backend.
///
/// ponytail: a remote item is not mirrored into SQLite, so the first launch
/// without a network shows the cache only. Mirror on read when offline stops
/// meaning "demo".

/// True while the last sync succeeded. The wardrobe screen shows a stale-data
/// banner off this instead of pretending an empty list is an empty wardrobe.
final wardrobeOnline = ValueNotifier<bool>(true);

/// Replaces the catalog with the owner's rows. No-op on the demo backend, and a
/// failed fetch leaves the local cache in place rather than blanking the UI.
///
/// Catches everything, not just `WardrobeException`: a DNS failure surfaces as
/// `AuthRetryableFetchException` from gotrue and used to escape `main()` as an
/// unhandled async error, freezing the app on the splash screen.
Future<void> loadWardrobeFromBackend() async {
  if (wardrobeService is DemoWardrobeService) return;
  try {
    final remote = await wardrobeService.items();
    try {
      await mirrorWardrobeCache(remote);
    } catch (_) {
      // No store open (a bare widget test): show the backend rows anyway.
      wardrobeItems.value = remote;
    }
    wardrobeOnline.value = true;
  } catch (_) {
    // Offline or signed out: keep what the file already holds.
    wardrobeOnline.value = false;
  }
}

/// Remote first, then the cache: a row the backend rejected must not look
/// saved.
Future<void> saveWardrobeItem(WardrobeItem item) async {
  final stored = await wardrobeService.save(item);
  await addWardrobeItem(stored);
}

/// Remote first, then the cache — same order, so a rejected delete keeps the
/// garment on screen instead of hiding a row that still exists.
Future<void> removeWardrobeItem(String id) async {
  await wardrobeService.remove(id);
  await deleteWardrobeItem(id);
}

/// Same order for a selection: one backend call, one local statement.
Future<void> removeWardrobeItems(Iterable<String> ids) async {
  final list = ids.toList();
  if (list.isEmpty) return;
  await wardrobeService.removeMany(list);
  await deleteWardrobeItems(list);
}
