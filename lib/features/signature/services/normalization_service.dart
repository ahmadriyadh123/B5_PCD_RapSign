import 'package:image/image.dart' as img;

/// Service untuk normalisasi ukuran citra.
/// Menyeragamkan dimensi output agar konsisten untuk feature extraction.
class NormalizationService {
  static const int defaultSize = 256;

  /// Resize ke dimensi target (square) tanpa mempertahankan aspek rasio.
  img.Image resizeSquare(img.Image source, {int size = defaultSize}) {
    return img.copyResize(source, width: size, height: size);
  }

  /// Resize dengan mempertahankan aspek rasio, lalu pad dengan background putih.
  img.Image resizeWithAspectRatio(img.Image source, {int size = defaultSize}) {
    final scale = size / (source.width > source.height ? source.width : source.height);
    final newW = (source.width * scale).toInt();
    final newH = (source.height * scale).toInt();

    final resized = img.copyResize(source, width: newW, height: newH);

    // Buat canvas putih dan letakkan gambar di tengah
    final result = img.Image(width: size, height: size);
    img.fill(result, color: img.ColorRgb8(255, 255, 255));

    final offsetX = (size - newW) ~/ 2;
    final offsetY = (size - newH) ~/ 2;
    img.compositeImage(result, resized, dstX: offsetX, dstY: offsetY);

    return result;
  }

  /// Normalisasi intensitas pixel ke range 0-255 (contrast stretching).
  img.Image normalizeIntensity(img.Image source) {
    int minVal = 255, maxVal = 0;

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final lum = img.getLuminance(source.getPixel(x, y)).toInt();
        if (lum < minVal) minVal = lum;
        if (lum > maxVal) maxVal = lum;
      }
    }

    if (maxVal == minVal) return source;

    final result = img.Image(width: source.width, height: source.height);
    final range = maxVal - minVal;

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final lum = img.getLuminance(source.getPixel(x, y)).toInt();
        final normalized = ((lum - minVal) * 255 ~/ range).clamp(0, 255);
        result.setPixel(x, y, img.ColorRgb8(normalized, normalized, normalized));
      }
    }
    return result;
  }
}
