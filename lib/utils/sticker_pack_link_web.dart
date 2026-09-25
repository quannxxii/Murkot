import 'dart:html' as html;

/// Reads `/s/<name>` stashed by `web/index.html` before Flutter rewrites the URL.
String? consumeStashedStickerPack() {
  final name = html.window.sessionStorage['murkot_sticker_pack'];
  if (name == null || name.isEmpty) return null;
  html.window.sessionStorage.remove('murkot_sticker_pack');
  return name;
}
