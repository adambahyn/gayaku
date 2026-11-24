import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../logic/garment_defaults.dart';
import '../logic/ids.dart';
import '../models/scan_result.dart';
import '../models/wardrobe.dart';

/// A wardrobe call that failed with a message the UI can show as-is.
class WardrobeException implements Exception {
  const WardrobeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The only seam between the wardrobe screens and the backend.
abstract class WardrobeService {
  /// Owner's items, newest scan first.
  Future<List<WardrobeItem>> items();

  /// Stores what the scanner review screen built, including its cutout image.
  Future<WardrobeItem> save(WardrobeItem item);

  /// Stores a bare [ScanResult], writing its PNG first. Kept for callers that
  /// have no [WardrobeItem] yet (tests); the screens use [save].
  Future<WardrobeItem> add(ScanResult scan, {String? name});

  Future<void> remove(String id);

  /// Removes several garments in one request — the batch delete path.
  Future<void> removeMany(List<String> ids);
}

/// Keeps items in memory for tests and for runs built without credentials.
///
/// ponytail: the cutout PNG is dropped — nothing reads it back. Replace by
/// passing real credentials to `flutter run` (see supabase/README.md).
class DemoWardrobeService implements WardrobeService {
  final _items = <WardrobeItem>[];
  var _seq = 0;

  @override
  Future<List<WardrobeItem>> items() async =>
      List.unmodifiable(_items.reversed);

  @override
  Future<WardrobeItem> save(WardrobeItem item) async {
    _items.add(item);
    return item;
  }

  @override
  Future<WardrobeItem> add(ScanResult scan, {String? name}) => save(
    WardrobeItem(
      id: 'demo-${++_seq}',
      name: _name(scan, name),
      label: scan.label,
      category: scan.category.id,
      subcategory: scan.label,
      imagePath: '',
      colorName: scan.colorName,
      color: scan.dominantColor,
      formality: scan.formality,
      occasions: defaultOccasions(scan.category.id),
      confidence: scan.confidence,
    ),
  );

  @override
  Future<void> remove(String id) async =>
      _items.removeWhere((item) => item.id == id);

  @override
  Future<void> removeMany(List<String> ids) async {
    final drop = ids.toSet();
    _items.removeWhere((item) => drop.contains(item.id));
  }
}

/// Postgres and Supabase Storage. `wardrobe_items.image_url` holds the object
/// path inside `cutouts` (`<uid>/<file>.png`); the bucket is private, so the
/// display URL is signed on read and refreshed on every sync.
class SupabaseWardrobeService implements WardrobeService {
  SupabaseWardrobeService(this._client);

  final sb.SupabaseClient _client;

  static const _table = 'wardrobe_items';
  static const _dir = wardrobeCutoutDirName;

  /// Columns the screens read; `select()` without them shipped every column
  /// including ones no widget touches.
  static const _columns =
      'id,name,label,category,subcategory,brand,color_name,dominant_color,'
      'formality,occasions,confidence,image_url';

  /// How many garments one sync pulls. The screen renders from the SQLite
  /// mirror, so this is a cache bound, not a page.
  ///
  /// ponytail: no cursor paging — add `.range()` plus store paging when an
  /// account really owns more than this.
  static const _syncLimit = 200;

  @override
  Future<List<WardrobeItem>> items({int limit = _syncLimit}) async {
    final rows = await _guard(
      () => _client
          .from(_table)
          .select(_columns)
          .order('created_at', ascending: false)
          .limit(limit),
    );
    final userId = _client.auth.currentUser?.id;
    final restored = await Future.wait(
      rows.map(
        (row) => _restoreLegacyImage(Map<String, dynamic>.from(row), userId),
      ),
    );
    return _withSignedUrls(restored);
  }

  @override
  Future<WardrobeItem> save(WardrobeItem item) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const WardrobeException(
        'Sesi login tidak ditemukan. Silakan masuk ulang.',
      );
    }
    final storagePath = await _uploadImage(item.imagePath, userId);
    // Edit of an existing row updates in place; insert with the id would hit
    // the primary key and surface as a misleading "not allowed" message.
    final row = await _guard(
      () => _client
          .from(_table)
          .upsert({
            if (item.id.isNotEmpty) 'id': item.id,
            'name': item.name,
            'label': item.label.isEmpty ? (item.subcategory ?? '') : item.label,
            'category': item.category,
            'subcategory': item.subcategory ?? item.label,
            'brand': item.brand,
            'color_name': item.colorName,
            'dominant_color': _hex(item.color),
            'formality': item.formality,
            'occasions': item.occasions.isEmpty
                ? defaultOccasions(item.category)
                : item.occasions,
            'confidence': item.confidence,
            'image_url': storagePath,
          }, onConflict: 'id')
          .select()
          .single(),
    );
    return (await _withSignedUrls([_toItem(row)])).single;
  }

  @override
  Future<WardrobeItem> add(ScanResult scan, {String? name}) async {
    final dir = await _cutoutDir();
    final id = newWardrobeItemId();
    final file = '$id.png';
    await File('$dir/$file').writeAsBytes(scan.cutoutPng, flush: true);

    try {
      return await save(
        WardrobeItem(
          id: id,
          name: _name(scan, name),
          label: scan.label,
          category: scan.category.id,
          subcategory: scan.label,
          imagePath: '$dir/$file',
          colorName: scan.colorName,
          color: scan.dominantColor,
          formality: scan.formality,
          occasions: defaultOccasions(scan.category.id),
          confidence: scan.confidence,
        ),
      );
    } catch (_) {
      // No row means the local cutout is orphaned; drop it.
      File('$dir/$file').delete().ignore();
      rethrow;
    }
  }

  @override
  Future<void> remove(String id) => removeMany([id]);

  /// One select, one delete and one storage call for the whole selection: the
  /// per-item loop this replaced cost three requests per garment.
  @override
  Future<void> removeMany(List<String> ids) async {
    if (ids.isEmpty) return;
    final rows = await _guard(
      () => _client.from(_table).select('image_url').inFilter('id', ids),
    );
    await _guard(() => _client.from(_table).delete().inFilter('id', ids));

    final paths = <String>[];
    for (final row in rows) {
      final path = _storagePathOf(row['image_url'] as String?);
      if (path != null) paths.add(path);
    }
    if (paths.isEmpty) return;
    await _storageGuard(() => _client.storage.from(_bucket).remove(paths));
  }

  static const _bucket = 'cutouts';

  /// Uploads a local cutout and returns its object path inside the bucket.
  Future<String> _uploadImage(String imagePath, String userId) async {
    if (imagePath.isEmpty) return '';
    final file = File(imagePath);
    if (!await file.exists()) {
      // Already stored: an old public URL or a bare object path.
      final path = _storagePathOf(imagePath);
      if (path != null) return path;
      throw WardrobeException('File hasil scan tidak ditemukan: $imagePath');
    }
    final storagePath = '$userId/${_basename(imagePath)}';
    try {
      final bytes = await _shrink(file);
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const sb.FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/png',
            ),
          );
      return storagePath;
    } on sb.StorageException catch (e, stack) {
      debugPrint('Supabase Storage upload failed ($storagePath): ${e.message}');
      debugPrint('$stack');
      throw WardrobeException(_friendly(e.message));
    }
  }

  /// Longest edge kept on upload; the grid decodes a tile per garment.
  static const _maxImageEdge = 768;

  Future<Uint8List> _shrink(File file) async {
    final bytes = await file.readAsBytes();
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _maxImageEdge,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      return data?.buffer.asUint8List() ?? bytes;
    } on Object catch (e) {
      debugPrint('Cutout resize skipped: $e');
      return bytes;
    }
  }

  /// Signed display URLs for the rows that still point into the bucket. One
  /// batch call per sync; a failure leaves the path in place (text still
  /// shows) instead of failing the whole wardrobe.
  Future<List<WardrobeItem>> _withSignedUrls(List<WardrobeItem> items) async {
    final paths = <String>[];
    for (final item in items) {
      final path = _storagePathOf(item.imagePath);
      if (path != null) paths.add(path);
    }
    if (paths.isEmpty) return items;
    final signed = <String, String>{};
    try {
      final results = await _client.storage
          .from(_bucket)
          .createSignedUrlsResult(paths, _signedUrlTtl);
      for (final result in results) {
        // A path that could not be signed is skipped, not fatal: the row keeps
        // its path and the tile falls back to the placeholder.
        if (result case sb.SignedUrlSuccess(:final path, :final signedUrl)) {
          if (signedUrl.isNotEmpty) signed[path] = signedUrl;
        }
      }
    } on sb.StorageException catch (e) {
      debugPrint('Supabase signed URLs failed: ${e.message}');
    }
    if (signed.isEmpty) return items;
    return [
      for (final item in items)
        signed[_storagePathOf(item.imagePath)] == null
            ? item
            : item.copyWith(imagePath: signed[_storagePathOf(item.imagePath)]),
    ];
  }

  /// Seven days: the mirror is rewritten on every sync, so an offline week is
  /// the worst case before images fall back to the placeholder.
  static const _signedUrlTtl = 60 * 60 * 24 * 7;

  /// Absolute path of a temporary cutout; used only before upload.
  Future<String> _cutoutDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_dir');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<WardrobeItem> _restoreLegacyImage(
    Map<String, dynamic> row,
    String? userId,
  ) async {
    final imageUrl = row['image_url'] as String? ?? '';
    if (imageUrl.isNotEmpty) return _toItem(row);

    final legacyName = row['image_file'] as String? ?? '';
    if (legacyName.isEmpty) {
      debugPrint('Wardrobe item ${row['id']} has no image_url.');
      return _toItem(row);
    }

    final docs = await getApplicationDocumentsDirectory();
    final candidates = [
      '${docs.path}/cutouts/$legacyName',
      '${docs.path}/garments/$legacyName',
    ];
    for (final path in candidates) {
      if (!await File(path).exists()) continue;
      if (userId == null) {
        row['image_url'] = path;
        return _toItem(row);
      }
      try {
        final restoredUrl = await _uploadImage(path, userId);
        await _guard(
          () => _client
              .from(_table)
              .update({'image_url': restoredUrl})
              .eq('id', row['id']),
        );
        row['image_url'] = restoredUrl;
        debugPrint('Restored legacy wardrobe image ${row['id']} from $path');
      } catch (error, stack) {
        debugPrint('Could not restore wardrobe image ${row['id']}: $error');
        debugPrint('$stack');
        row['image_url'] = path;
      }
      return _toItem(row);
    }

    debugPrint(
      'Wardrobe item ${row['id']} references missing local image $legacyName.',
    );
    return _toItem(row);
  }

  WardrobeItem _toItem(Map<String, dynamic> row) {
    final imageUrl = row['image_url'] as String? ?? '';
    final category = row['category'] as String;
    final subcategory = row['subcategory'] as String? ?? '';
    final occasions = (row['occasions'] as List?)?.cast<String>() ?? const [];
    return WardrobeItem(
      id: row['id'] as String,
      name: row['name'] as String,
      label: row['label'] as String? ?? '',
      category: category,
      subcategory: subcategory.isEmpty ? null : subcategory,
      brand: row['brand'] as String? ?? '',
      imagePath: imageUrl,
      colorName: row['color_name'] as String? ?? '',
      color: _hexColor(row['dominant_color'] as String?),
      formality: (row['formality'] as num?)?.toInt() ?? 3,
      // A row written before the `occasions` column falls back to the same
      // default the scanner applies, so old and new items match alike.
      occasions: occasions.isEmpty ? defaultOccasions(category) : occasions,
      confidence: (row['confidence'] as num?)?.toDouble(),
    );
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (e) {
      debugPrint('Supabase database request failed: ${e.message}');
      throw WardrobeException(_friendly(e.message));
    } on sb.AuthException catch (e) {
      debugPrint('Supabase auth failed: ${e.message}');
      throw WardrobeException(_friendly(e.message));
    } on SocketException catch (e) {
      debugPrint('Supabase unreachable: $e');
      throw const WardrobeException(_offline);
    }
  }

  Future<T> _storageGuard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.StorageException catch (e, stack) {
      debugPrint('Supabase Storage request failed: ${e.message}');
      debugPrint('$stack');
      throw WardrobeException(_friendly(e.message));
    } on SocketException catch (e) {
      debugPrint('Supabase Storage unreachable: $e');
      throw const WardrobeException(_offline);
    }
  }

  static const _offline =
      'Tidak ada koneksi. Perubahan belum tersimpan di server.';

  /// The screen shows these strings as-is, so an unmatched Postgres message is
  /// replaced by a generic one instead of leaking constraint and column names.
  static String _friendly(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('row-level security') || lower.contains('violates')) {
      return 'Tidak diizinkan menyimpan item ini.';
    }

    if (lower.contains('jwt') || lower.contains('expired')) {
      return 'Sesi habis, masuk ulang.';
    }
    if (lower.contains('duplicate key')) {
      return 'Item ini sudah ada di lemarimu.';
    }
    if (lower.contains('payload') || lower.contains('too large')) {
      return 'Gambar terlalu besar untuk diunggah.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('connection')) {
      return _offline;
    }
    debugPrint('Unmapped Supabase error: $message');
    return 'Permintaan ke server gagal. Coba lagi.';
  }
}

/// The object path inside `cutouts`, or null for a local file / empty value.
String? _storagePathOf(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return _storagePathFromUrl(value);
  }
  if (value.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) {
    return null;
  }
  return value;
}

String? _storagePathFromUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  final bucketIndex = segments.indexOf('cutouts');
  if (bucketIndex == -1 || bucketIndex == segments.length - 1) return null;
  return segments.sublist(bucketIndex + 1).join('/');
}

String _name(ScanResult scan, String? override) {
  final name = (override ?? scan.suggestedName).trim();
  return name.isEmpty ? scan.label : name;
}

String _basename(String path) =>
    path.isEmpty ? '' : path.split(RegExp(r'[\\/]')).last;

/// Color to the `#RRGGBB` the dominant_color check accepts.
String _hex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// `#RRGGBB` back to a Color; a malformed value falls back to the app's tan.
Color _hexColor(String? value) {
  final digits = (value ?? '').replaceFirst('#', '');
  final parsed = digits.length == 6 ? int.tryParse(digits, radix: 16) : null;
  return parsed == null ? const Color(0xFFD3A277) : Color(0xFF000000 | parsed);
}

WardrobeService _wardrobe = DemoWardrobeService();

/// The wardrobe backend the screens talk to. Defaults to [DemoWardrobeService];
/// [main] swaps in [SupabaseWardrobeService] when credentials are compiled in.
WardrobeService get wardrobeService => _wardrobe;

/// Swaps the backend; called once from [main] before the first frame.
void useWardrobeService(WardrobeService service) => _wardrobe = service;
