import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sticker_packs.dart';

class StickerPackPreview {
  const StickerPackPreview({
    required this.id,
    required this.title,
    required this.shortName,
    required this.isOwner,
    required this.isInstalled,
    required this.stickers,
  });

  final String id;
  final String title;
  final String shortName;
  final bool isOwner;
  final bool isInstalled;
  final List<StickerItem> stickers;

  StickerPackPreview copyWith({bool? isInstalled}) {
    return StickerPackPreview(
      id: id,
      title: title,
      shortName: shortName,
      isOwner: isOwner,
      isInstalled: isInstalled ?? this.isInstalled,
      stickers: stickers,
    );
  }
}

class StickerPackService {
  StickerPackService();

  final _client = Supabase.instance.client;

  /// Owned packs plus packs installed from a `/s/<name>` link.
  /// Falls back to the owner-only table if features_v31.sql is not applied yet.
  Future<List<StickerPack>> loadMine() async {
    try {
      final rows = await _client.rpc('list_my_sticker_packs');
      return _packsFromRows(rows);
    } catch (e) {
      debugPrint('list_my_sticker_packs failed: $e');
      return _loadOwnTable();
    }
  }

  Future<String> createPack(String title) async {
    final id = await _client.rpc(
      'create_my_sticker_pack',
      params: {'p_title': title.trim()},
    );
    return id as String;
  }

  Future<void> install(String shortName) async {
    await _client.rpc(
      'install_sticker_pack',
      params: {'p_short_name': shortName.trim().toLowerCase()},
    );
  }

  /// Public preview for `/s/<name>`. Null when the pack does not exist.
  Future<StickerPackPreview?> preview(String shortName) async {
    final rows = await _client.rpc(
      'get_sticker_pack',
      params: {'p_short_name': shortName.trim().toLowerCase()},
    );
    if (rows is! List || rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first as Map);
    final id = row['id'] as String?;
    final title = (row['title'] as String?)?.trim();
    final name = (row['short_name'] as String?)?.trim();
    if (id == null || title == null || title.isEmpty || name == null) {
      return null;
    }
    return StickerPackPreview(
      id: id,
      title: title,
      shortName: name,
      isOwner: row['is_owner'] == true,
      isInstalled: row['is_installed'] == true,
      stickers: _stickerItems(row['stickers']),
    );
  }

  Future<void> deleteSticker(String stickerId) async {
    await _client.rpc(
      'delete_my_sticker',
      params: {'p_sticker_id': stickerId},
    );
  }

  Future<void> deletePack(String packId) async {
    await _client.rpc(
      'delete_my_sticker_pack',
      params: {'p_pack_id': packId},
    );
  }

  Future<void> addImage({
    required String packId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final url = await _upload(bytes, fileName);
    await _client.rpc(
      'add_my_sticker',
      params: {'p_pack_id': packId, 'p_image_url': url},
    );
  }

  Future<List<StickerPack>> _loadOwnTable() async {
    try {
      final rows = await _client
          .from('sticker_packs')
          .select('id, title, short_name, stickers(id, image_url, position)')
          .order('created_at', ascending: false);
      return _packsFromRows(rows, ownedFallback: true);
    } catch (e) {
      debugPrint('sticker short_name column missing: $e');
      final rows = await _client
          .from('sticker_packs')
          .select('id, title, stickers(id, image_url, position)')
          .order('created_at', ascending: false);
      return _packsFromRows(rows, ownedFallback: true);
    }
  }

  Future<String> _upload(Uint8List bytes, String fileName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path =
        '$userId/stickers/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final lower = safeName.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : lower.endsWith('.gif')
                ? 'image/gif'
                : 'image/jpeg';
    await _client.storage.from('chat-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return _client.storage.from('chat-media').getPublicUrl(path);
  }

  List<StickerPack> _packsFromRows(dynamic rows, {bool ownedFallback = false}) {
    final packs = <StickerPack>[];
    for (final row in rows as List) {
      final pack = _packFromRow(
        Map<String, dynamic>.from(row as Map),
        ownedFallback: ownedFallback,
      );
      if (pack == null) continue;
      if (pack.stickers.isEmpty && !pack.isOwner) continue;
      packs.add(pack);
    }
    return packs;
  }

  StickerPack? _packFromRow(
    Map<String, dynamic> row, {
    required bool ownedFallback,
  }) {
    final id = row['id'] as String?;
    final title = (row['title'] as String?)?.trim();
    if (id == null || title == null || title.isEmpty) return null;

    final shortName = (row['short_name'] as String?)?.trim();
    final isOwner = ownedFallback || row['is_owner'] == true;

    return StickerPack(
      id: id,
      titleRu: title,
      titleEn: title,
      shortName: (shortName == null || shortName.isEmpty) ? null : shortName,
      isOwner: isOwner,
      stickers: _stickerItems(row['stickers']),
    );
  }

  List<StickerItem> _stickerItems(dynamic raw) {
    final list = _asMapList(raw)
      ..sort((a, b) => _asInt(a['position']).compareTo(_asInt(b['position'])));
    return [
      for (final item in list)
        if ((item['image_url'] as String?)?.isNotEmpty ?? false)
          StickerItem(
            id: item['id'] as String,
            imageUrl: item['image_url'] as String,
          ),
    ];
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      return _asMapList(decoded);
    }
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
