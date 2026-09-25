import 'package:flutter/foundation.dart';

import 'sticker_pack_link_stub.dart'
    if (dart.library.html) 'sticker_pack_link_web.dart' as stash;

/// Pending `/s/<name>` consumed after sign-in.
final ValueNotifier<String?> pendingStickerPack = ValueNotifier<String?>(null);

final _nameRe = RegExp(r'^[A-Za-z0-9_]{3,32}$');

bool isValidStickerPackName(String name) => _nameRe.hasMatch(name);

String? extractStickerPackName(Uri uri) {
  final fromFragment = _nameFromPath(
    uri.fragment.isEmpty
        ? ''
        : (uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}'),
  );
  if (fromFragment != null) return fromFragment;
  return _nameFromPath(uri.path);
}

String? _nameFromPath(String path) {
  if (path.isEmpty) return null;
  final segs =
      path.split('/').where((s) => s.isNotEmpty && s != 'index.html').toList();
  for (var i = 0; i < segs.length - 1; i++) {
    if (segs[i].toLowerCase() == 's' && isValidStickerPackName(segs[i + 1])) {
      return segs[i + 1].toLowerCase();
    }
  }
  return null;
}

void captureInitialStickerPackLink() {
  if (!kIsWeb) return;
  final name = extractStickerPackName(Uri.base) ?? stash.consumeStashedStickerPack();
  if (name != null && isValidStickerPackName(name)) {
    pendingStickerPack.value = name.toLowerCase();
  }
}

String buildPublicStickerPackUrl(String shortName) {
  final clean = shortName.trim().toLowerCase();
  if (kIsWeb) {
    final base = Uri.base;
    final segs = base.path
        .split('/')
        .where((s) => s.isNotEmpty && s != 'index.html' && s.toLowerCase() != 's')
        .toList();
    if (segs.isNotEmpty && isValidStickerPackName(segs.last)) {
      segs.removeLast();
    }
    final keepPrefix = segs.length == 1 && segs.first == 'Murkot';
    final prefix = keepPrefix ? '/Murkot' : '';
    return base
        .replace(path: '$prefix/s/$clean', query: '', fragment: '')
        .toString();
  }
  return 'https://murkot.vercel.app/s/$clean';
}

String? consumePendingStickerPack() {
  final name = pendingStickerPack.value;
  if (name == null) return null;
  pendingStickerPack.value = null;
  return name;
}
