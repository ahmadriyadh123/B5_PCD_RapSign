import 'package:image/image.dart' as img;

/// Service untuk ekstraksi Region of Interest (ROI) tanda tangan.
/// Algoritma:
/// 1. Crop area dokumen putih
/// 2. Scan dari bawah ke atas, cari di mana ada coretan/tulisan (pixel gelap)
/// 3. Crop bounding box area coretan tersebut
class RoiExtractionService {
  static const int _whiteThreshold = 180;
  static const double _rowWhiteRatio = 0.5;
  /// Pixel dianggap "tinta/coretan" jika luminance di bawah ini
  static const int _inkThreshold = 150;
  /// Minimal pixel gelap per baris untuk dianggap ada tulisan
  static const int _minInkPixelsPerRow = 5;

  /// Pipeline: crop dokumen → deteksi posisi coretan di bawah.
  img.Image extractFromDocument(img.Image source) {
    final doc = cropWhiteDocument(source);
    return detectInkFromBottom(doc);
  }

  /// Crop area dokumen putih dari frame.
  img.Image cropWhiteDocument(img.Image source) {
    final w = source.width;
    final h = source.height;
    final minWhitePerRow = (w * _rowWhiteRatio).toInt();

    int bestStart = 0, bestEnd = h - 1, bestLen = 0, start = -1;
    for (int y = 0; y < h; y++) {
      int whiteCount = 0;
      for (int x = 0; x < w; x++) {
        final p = source.getPixel(x, y);
        if (p.r >= _whiteThreshold && p.g >= _whiteThreshold && p.b >= _whiteThreshold) {
          whiteCount++;
        }
      }
      if (whiteCount >= minWhitePerRow) {
        if (start == -1) start = y;
      } else {
        if (start != -1 && (y - start) > bestLen) {
          bestLen = y - start;
          bestStart = start;
          bestEnd = y - 1;
        }
        start = -1;
      }
    }
    if (start != -1 && (h - start) > bestLen) {
      bestLen = h - start;
      bestStart = start;
      bestEnd = h - 1;
    }
    if (bestLen < 50) return source;

    // Batas horizontal
    final colWhite = List.filled(w, 0);
    for (int y = bestStart; y <= bestEnd; y++) {
      for (int x = 0; x < w; x++) {
        final p = source.getPixel(x, y);
        if (p.r >= _whiteThreshold && p.g >= _whiteThreshold && p.b >= _whiteThreshold) {
          colWhite[x]++;
        }
      }
    }
    final docH = bestEnd - bestStart + 1;
    final minPerCol = (docH * _rowWhiteRatio).toInt();
    int startX = 0, endX = w - 1;
    for (int x = 0; x < w; x++) {
      if (colWhite[x] >= minPerCol) { startX = x; break; }
    }
    for (int x = w - 1; x >= 0; x--) {
      if (colWhite[x] >= minPerCol) { endX = x; break; }
    }

    final cropW = endX - startX + 1;
    if (cropW < 50 || docH < 50) return source;
    return img.copyCrop(source, x: startX, y: bestStart, width: cropW, height: docH);
  }

  /// Scan dari bawah ke atas, cari coretan paling bawah,
  /// lalu lanjut ke atas sampai ketemu coretan terdekat di atasnya.
  /// Stop ketika ada gap kosong setelah coretan kedua.
  img.Image detectInkFromBottom(img.Image source) {
    final w = source.width;
    final h = source.height;
    final grayscale = img.grayscale(source);

    int inkBottomY = -1;
    int inkTopY = -1;
    int inkLeftX = w;
    int inkRightX = 0;
    int gapCount = 0;
    bool foundFirstBlock = false;

    // Scan dari bawah ke atas
    for (int y = h - 1; y >= 0; y--) {
      int inkCount = 0;
      for (int x = 0; x < w; x++) {
        if (img.getLuminance(grayscale.getPixel(x, y)).toInt() < _inkThreshold) {
          inkCount++;
        }
      }
      if (inkCount >= _minInkPixelsPerRow) {
        if (inkBottomY == -1) inkBottomY = y;
        inkTopY = y;
        if (gapCount > 0) foundFirstBlock = true; // ada gap sebelumnya = ini blok kedua
        gapCount = 0;
      } else {
        if (inkBottomY != -1) gapCount++;
        // Jika sudah melewati 2 blok coretan dan ketemu gap besar → stop
        if (foundFirstBlock && gapCount > 30) break;
        // Jika baru 1 blok dan gap kecil, lanjut cari blok berikutnya di atas
        // Jika gap terlalu besar tanpa blok kedua → stop juga
        if (!foundFirstBlock && gapCount > 80) break;
      }
    }

    if (inkBottomY == -1) return source;

    // Cari batas horizontal
    for (int y = inkTopY; y <= inkBottomY; y++) {
      for (int x = 0; x < w; x++) {
        if (img.getLuminance(grayscale.getPixel(x, y)).toInt() < _inkThreshold) {
          if (x < inkLeftX) inkLeftX = x;
          if (x > inkRightX) inkRightX = x;
        }
      }
    }

    // Padding
    const padding = 20;
    inkTopY = (inkTopY - padding).clamp(0, h - 1);
    inkBottomY = (inkBottomY + padding).clamp(0, h - 1);
    inkLeftX = (inkLeftX - padding).clamp(0, w - 1);
    inkRightX = (inkRightX + padding).clamp(0, w - 1);

    return img.copyCrop(
      source,
      x: inkLeftX,
      y: inkTopY,
      width: inkRightX - inkLeftX + 1,
      height: inkBottomY - inkTopY + 1,
    );
  }
}
