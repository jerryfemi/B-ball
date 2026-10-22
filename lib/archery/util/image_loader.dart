import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Centralized utility to load asset images into raw [ui.Image] instances.
Future<ui.Image> loadArcheryImage(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}
