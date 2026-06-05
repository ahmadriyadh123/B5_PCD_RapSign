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

  /// Scan dan temukan blok tanda tangan menggunakan Horizontal Projection Profile.
  /// Metode ini lebih tangguh terhadap teks footer atau noise kecil di bagian bawah.
  RoiCropResult detectInkFromBottom(RoiCropResult docCrop) {
    final source = docCrop.image;
    final w = source.width;
    final h = source.height;
    final grayscale = img.grayscale(source);

    // 1. Horizontal Projection: Hitung tinta per baris
    final rowInkCount = List.filled(h, 0);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (img.getLuminance(grayscale.getPixel(x, y)).toInt() < _inkThreshold) {
          rowInkCount[y]++;
        }
      }
    }

    // 2. Segmentasi menjadi blok-blok kandidat
    List<({int top, int bottom, int height})> candidates = [];
    int? startY;
    for (int y = 0; y < h; y++) {
      if (rowInkCount[y] >= _minInkPixelsPerRow) {
        startY ??= y;
      } else {
        if (startY != null) {
          final blockHeight = y - startY;
          // Filter: Tanda tangan biasanya memiliki tinggi yang signifikan (> 30px)
          // Teks footer atau garis biasanya sangat tipis.
          if (blockHeight > 25) {
            candidates.add((top: startY, bottom: y - 1, height: blockHeight));
          }
          startY = null;
        }
      }
    }

    // Jika scan selesai dan masih ada blok yang menggantung
    if (startY != null) {
      final blockHeight = h - startY;
      if (blockHeight > 25) {
        candidates.add((top: startY, bottom: h - 1, height: blockHeight));
      }
    }

    if (candidates.isEmpty) {
      // Jika tidak ada blok besar, coba cari yang kecil (mungkin tanda tangan kecil)
      // atau kembalikan dokumen asli jika benar-benar kosong.
      return docCrop;
    }

    // 3. Pemilihan Kandidat: Ambil yang paling bawah yang memenuhi kriteria
    // Karena biasanya tanda tangan ada di bagian bawah area dokumen.
    final bestBlock = candidates.last;
    int inkTopY = bestBlock.top;
    int inkBottomY = bestBlock.bottom;

    // 4. Cari batas horizontal (kiri-kanan) hanya pada blok terpilih
    int inkLeftX = w;
    int inkRightX = 0;
    for (int y = inkTopY; y <= inkBottomY; y++) {
      for (int x = 0; x < w; x++) {
        if (img.getLuminance(grayscale.getPixel(x, y)).toInt() < _inkThreshold) {
          if (x < inkLeftX) inkLeftX = x;
          if (x > inkRightX) inkRightX = x;
        }
      }
    }

    // Jika tidak ditemukan tinta secara horizontal (kasus langka)
    if (inkLeftX > inkRightX) return docCrop;

    // 5. Padding & Cropping
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

    return RoiCropResult(
      image: cropped,
      x: docCrop.x + inkLeftX,
      y: docCrop.y + inkTopY,
      width: cropWidth,
      height: cropHeight,
    );
  }
}