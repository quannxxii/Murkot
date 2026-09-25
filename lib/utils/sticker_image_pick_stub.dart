import 'package:image_picker/image_picker.dart';

import 'sticker_image_pick_types.dart';

Future<List<PickedStickerImage>> pickStickerImages() async {
  final files = await ImagePicker().pickMultiImage(imageQuality: 85);
  final picked = <PickedStickerImage>[];
  for (final file in files) {
    picked.add(
      PickedStickerImage(
        bytes: await file.readAsBytes(),
        name: file.name.isEmpty ? 'sticker.png' : file.name,
      ),
    );
  }
  return picked;
}
