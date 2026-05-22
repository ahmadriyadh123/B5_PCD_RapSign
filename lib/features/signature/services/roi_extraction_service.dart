import 'package:image/image.dart' as img;
class RoiCropResult {
  final img.Image image;
  final int x;
  final int y;
  final int width;
  final int height;

  RoiCropResult({
    required this.image,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Service untuk ekstraksi Region of Interest (ROI) tanda tangan.
class RoiExtractionService {
  static const int _whiteThreshold = 180;
  static const double _rowWhiteRatio = 0.5;
  static const int _inkThreshold = 150;
  static const int _minInkPixelsPerRow = 5;

  /// Pipeline: crop dokumen → deteksi posisi coretan di bawah.
  RoiCropResult extractFromDocument(img.Image source) {
    final docCrop = cropWhiteDocument(source);
    return detectInkFromBottom(docCrop);
  }

  /// Crop area dokumen putih dari frame.
  RoiCropResult cropWhiteDocument(img.Image source) {
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
    
    if (bestLen < 50) {
      return RoiCropResult(image: source, x: 0, y: 0, width: w, height: h);
    }

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
    if (cropW < 50 || docH < 50) {
      return RoiCropResult(image: source, x: 0, y: 0, width: w, height: h);
    }
    
    final cropped = img.copyCrop(source, x: startX, y: bestStart, width: cropW, height: docH);
    return RoiCropResult(image: cropped, x: startX, y: bestStart, width: cropW, height: docH);
  }

  /// Scan dari bawah ke atas menggunakan input hasil crop sebelumnya.
  RoiCropResult detectInkFromBottom(RoiCropResult docCrop) {
    final source = docCrop.image;
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
        if (gapCount > 0) foundFirstBlock = true;
        gapCount = 0;
      } else {
        if (inkBottomY != -1) gapCount++;
        if (foundFirstBlock && gapCount > 30) break;
        if (!foundFirstBlock && gapCount > 80) break;
      }
    }

    if (inkBottomY == -1) return docCrop; // Kembalikan docCrop asli jika tidak ketemu

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

    final cropWidth = inkRightX - inkLeftX + 1;
    final cropHeight = inkBottomY - inkTopY + 1;

    final cropped = img.copyCrop(
      source,
      x: inkLeftX,
      y: inkTopY,
      width: cropWidth,
      height: cropHeight,
    );

    // Mengakumulasi koordinat untuk mendapatkan posisi absolut di original frame
    return RoiCropResult(
      image: cropped,
      x: docCrop.x + inkLeftX,
      y: docCrop.y + inkTopY,
      width: cropWidth,
      height: cropHeight,
    );
  }
}