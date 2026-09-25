import 'dart:typed_data';

class PickedStickerImage {
  const PickedStickerImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}
