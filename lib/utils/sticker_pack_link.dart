import 'dart:convert';

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

final _packInText = RegExp(
  r'(?:https?:\/\/\S+)?\/s\/([A-Za-z0-9_]{3,32})(?=\/|\s|$)',
  caseSensitive: false,
);

final _onlyPackLink = RegExp(
  r'^\s*(?:https?:\/\/\S+)?\/s\/[A-Za-z0-9_]{3,32}\/?\s*$',
  caseSensitive: false,
);

/// Short name from a chat message that contains `/s/<name>`.
String? stickerPackNameFromText(String text) {
  final match = _packInText.firstMatch(text.trim());
  final name = match?.group(1)?.toLowerCase();
  if (name == null || !isValidStickerPackName(name)) return null;
  return name;
}

/// True when the message is only a sticker-pack link.
bool isStickerPackLinkMessage(String text) => _onlyPackLink.hasMatch(text.trim());

/// Pack link plus the public sticker URLs needed to copy it.
class SharedStickerPackLink {
  const SharedStickerPackLink({
    required this.shortName,
    required this.title,
    required this.imageUrls,
  });

  final String shortName;
  final String title;
  final List<String> imageUrls;
}

const _packMarker = 'murkotStickerPack';

String encodeSharedStickerPack({
  required String shortName,
  required String title,
  required List<String> imageUrls,
}) {
  return jsonEncode({
    _packMarker: {
      'name': shortName,
      'title': title,
      'images': imageUrls,
    },
  });
}

/// JSON from a sent pack link, or a plain `/s/<name>` URL with no images.
SharedStickerPackLink? decodeSharedStickerPack(String content) {
  final trimmed = content.trim();
  if (trimmed.startsWith('{') && trimmed.contains(_packMarker)) {
    try {
      final map = jsonDecode(trimmed);
      if (map is! Map) return null;
      final pack = map[_packMarker];
      if (pack is! Map) return null;
      final name = pack['name']?.toString().trim().toLowerCase() ?? '';
      if (!isValidStickerPackName(name)) return null;
      final title = (pack['title'] as String?)?.trim();
      final images = <String>[];
      final raw = pack['images'];
      if (raw is List) {
        for (final item in raw) {
          final url = item?.toString() ?? '';
          if (url.startsWith('http://') || url.startsWith('https://')) {
            images.add(url);
          }
        }
      }
      return SharedStickerPackLink(
        shortName: name,
        title: (title == null || title.isEmpty) ? name : title,
        imageUrls: images,
      );
    } catch (_) {
      return null;
    }
  }
  final name = stickerPackNameFromText(trimmed);
  if (name == null) return null;
  return SharedStickerPackLink(shortName: name, title: name, imageUrls: const []);
}

String? consumePendingStickerPack() {
  final name = pendingStickerPack.value;
  if (name == null) return null;
  pendingStickerPack.value = null;
  return name;
}
