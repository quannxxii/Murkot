import 'sticker_image_pick_stub.dart'
    if (dart.library.html) 'sticker_image_pick_web.dart' as impl;
import 'sticker_image_pick_types.dart';

export 'sticker_image_pick_types.dart';

Future<List<PickedStickerImage>> pickStickerImages() => impl.pickStickerImages();
