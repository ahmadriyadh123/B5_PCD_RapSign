import 'package:image/image.dart' as img;

/// Service untuk ekstraksi Region of Interest (ROI) tanda tangan.
/// Mendeteksi area tanda tangan dan memotong area yang relevan.
class RoiExtractionService {
  /// Crop bagian bawah dokumen (area umum tanda tangan).
  /// [bottomRatio] menentukan proporsi bawah yang diambil (default 40%).
  img.Image cropBottomRegion(img.Image source, {double bottomRatio = 0.4}) {
    final startY = (source.height * (1 - bottomRatio)).toInt();
    return img.copyCrop(
      source,
      x: 0,
      y: startY,
      width: source.width,
      height: source.height - startY,
    );
  }

  /// Deteksi bounding box tanda tangan berdasarkan pixel gelap (ink).
  /// Mengembalikan cropped image yang hanya berisi area tanda tangan.
  img.Image extractSignatureRegion(img.Image source, {int threshold = 128, int padding = 20}) {
    int minX = source.width, minY = source.height, maxX = 0, maxY = 0;
    bool found = false;

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final gray = (img.getLuminance(pixel)).toInt();
        if (gray < threshold) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
          found = true;
        }
      }
    }

    if (!found) return source;

    // Tambah padding
    minX = (minX - padding).clamp(0, source.width - 1);
    minY = (minY - padding).clamp(0, source.height - 1);
    maxX = (maxX + padding).clamp(0, source.width - 1);
    maxY = (maxY + padding).clamp(0, source.height - 1);

    return img.copyCrop(
      source,
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );
  }

  /// Pipeline lengkap: crop bawah dokumen lalu ekstrak area tanda tangan.
  img.Image extractFromDocument(img.Image document, {double bottomRatio = 0.4, int threshold = 128}) {
    final bottomRegion = cropBottomRegion(document, bottomRatio: bottomRatio);
    return extractSignatureRegion(bottomRegion, threshold: threshold);
  }
}
