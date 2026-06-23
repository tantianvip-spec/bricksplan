import 'dart:io';
import 'package:image/image.dart' as img;

Future<String> compressImage(String sourcePath, {int maxDimension = 1600, int quality = 85}) async {
  final original = img.decodeImage(File(sourcePath).readAsBytesSync());
  if (original == null) return sourcePath;

  final image = original.width > original.height
      ? img.copyResize(original, width: maxDimension)
      : img.copyResize(original, height: maxDimension);

  final compressed = img.encodeJpg(image, quality: quality);
  final outPath = '${sourcePath}_compressed.jpg';
  await File(outPath).writeAsBytes(compressed);
  return outPath;
}
