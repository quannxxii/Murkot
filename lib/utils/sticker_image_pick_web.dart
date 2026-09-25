import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'sticker_image_pick_types.dart';

/// Opens the file dialog in the same turn as the tap.
/// Release builds on Vercel lose the browser gesture if this goes through
/// ImagePicker, and then the chosen file never gets read.
Future<List<PickedStickerImage>> pickStickerImages() {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = true
    ..style.display = 'none';
  final completer = Completer<List<PickedStickerImage>>();

  input.onChange.listen((_) async {
    if (completer.isCompleted) return;
    try {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(const []);
        return;
      }
      final picked = <PickedStickerImage>[];
      for (final file in files) {
        picked.add(
          PickedStickerImage(
            bytes: await _readFile(file),
            name: file.name.isEmpty ? 'sticker.png' : file.name,
          ),
        );
      }
      completer.complete(picked);
    } catch (e, stack) {
      if (!completer.isCompleted) completer.completeError(e, stack);
    } finally {
      input.remove();
    }
  });

  input.on['cancel'].listen((_) {
    if (!completer.isCompleted) completer.complete(const []);
    input.remove();
  });

  html.document.body?.append(input);
  input.click();
  return completer.future;
}

Future<Uint8List> _readFile(html.File file) {
  final reader = html.FileReader();
  final done = Completer<Uint8List>();
  reader.onLoadEnd.listen((_) {
    if (done.isCompleted) return;
    final result = reader.result;
    if (result is Uint8List) {
      done.complete(result);
    } else if (result is ByteBuffer) {
      done.complete(Uint8List.view(result));
    } else {
      done.completeError(StateError('Could not read image'));
    }
  });
  reader.onError.listen((_) {
    if (!done.isCompleted) {
      done.completeError(StateError('Could not read image'));
    }
  });
  reader.readAsArrayBuffer(file);
  return done.future;
}
