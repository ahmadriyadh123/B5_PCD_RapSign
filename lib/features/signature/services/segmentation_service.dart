import 'dart:math';
import 'package:image/image.dart' as img;

/// Hasil segmentasi dokumen.
class DocumentSegmentationResult {
  final img.Image documentImage;
  final bool isDocumentDetected;
  final double documentAreaRatio; // rasio area dokumen terhadap total frame

  DocumentSegmentationResult({
    required this.documentImage,
    required this.isDocumentDetected,
    required this.documentAreaRatio,
  });
}

/// Service untuk segmentasi citra - memisahkan dokumen dari background
/// dan tanda tangan dari kertas.
class SegmentationService {
  /// Segmentasi dokumen vs background.
  /// Mendeteksi area kertas putih/terang di dalam frame kamera.
  DocumentSegmentationResult segmentDocument(img.Image source) {
    final grayscale = img.grayscale(source);
    final w = grayscale.width;
    final h = grayscale.height;

    // Otsu threshold untuk pisahkan kertas (terang) dari background (gelap)
    final threshold = _otsuThreshold(grayscale);

    // Buat mask: pixel terang = dokumen
    final mask = List.generate(h, (_) => List.filled(w, false));
    int docPixels = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final lum = img.getLuminance(grayscale.getPixel(x, y)).toInt();
        if (lum >= threshold) {
          mask[y][x] = true;
          docPixels++;
        }
      }
    }

    final totalPixels = w * h;
    final ratio = docPixels / totalPixels;
    // Dokumen terdeteksi jika area terang antara 20%-90% frame
    final detected = ratio > 0.2 && ratio < 0.9;

    if (!detected) {
      return DocumentSegmentationResult(
        documentImage: source,
        isDocumentDetected: false,
        documentAreaRatio: ratio,
      );
    }

    // Cari bounding box area dokumen
    int minX = w, minY = h, maxX = 0, maxY = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (mask[y][x]) {
          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }

    final cropW = maxX - minX + 1;
    final cropH = maxY - minY + 1;
    if (cropW < 50 || cropH < 50) {
      return DocumentSegmentationResult(
        documentImage: source,
        isDocumentDetected: false,
        documentAreaRatio: ratio,
      );
    }

    final cropped = img.copyCrop(source, x: minX, y: minY, width: cropW, height: cropH);
    return DocumentSegmentationResult(
      documentImage: cropped,
      isDocumentDetected: true,
      documentAreaRatio: ratio,
    );
  }

  /// Binary threshold sederhana.
  img.Image binaryThreshold(img.Image source, {int threshold = 128}) {
    final grayscale = img.grayscale(source);
    final result = img.Image(width: grayscale.width, height: grayscale.height);

    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        final lum = img.getLuminance(grayscale.getPixel(x, y)).toInt();
        final val = lum < threshold ? 0 : 255;
        result.setPixel(x, y, img.ColorRgb8(val, val, val));
      }
    }
    return result;
  }

  /// Adaptive threshold menggunakan integral image — O(n) per pixel.
  img.Image adaptiveThreshold(img.Image source, {int blockSize = 15, int c = 10}) {
    final grayscale = img.grayscale(source);
    final w = grayscale.width;
    final h = grayscale.height;

    // Build integral image
    final integral = List.generate(h + 1, (_) => List.filled(w + 1, 0));
    for (int y = 1; y <= h; y++) {
      for (int x = 1; x <= w; x++) {
        final lum = img.getLuminance(grayscale.getPixel(x - 1, y - 1)).toInt();
        integral[y][x] = lum + integral[y - 1][x] + integral[y][x - 1] - integral[y - 1][x - 1];
      }
    }

    final result = img.Image(width: w, height: h);
    final half = blockSize ~/ 2;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        // Batas window
        final x1 = max(0, x - half);
        final y1 = max(0, y - half);
        final x2 = min(w - 1, x + half);
        final y2 = min(h - 1, y + half);

        final count = (x2 - x1 + 1) * (y2 - y1 + 1);
        // Sum dari integral image: S(x1,y1,x2,y2)
        final sum = integral[y2 + 1][x2 + 1] - integral[y1][x2 + 1] - integral[y2 + 1][x1] + integral[y1][x1];
        final mean = sum ~/ count;

        final lum = img.getLuminance(grayscale.getPixel(x, y)).toInt();
        final val = lum < (mean - c) ? 0 : 255;
        result.setPixel(x, y, img.ColorRgb8(val, val, val));
      }
    }
    return result;
  }

  /// Masking: hapus background dan pertahankan hanya foreground (tinta).
  img.Image applyMask(img.Image source, img.Image binaryMask) {
    final result = img.Image(width: source.width, height: source.height);
    img.fill(result, color: img.ColorRgb8(255, 255, 255));

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final maskPixel = img.getLuminance(binaryMask.getPixel(x, y)).toInt();
        if (maskPixel == 0) {
          result.setPixel(x, y, source.getPixel(x, y));
        }
      }
    }
    return result;
  }

  /// Otsu's method untuk menentukan threshold optimal secara otomatis.
  int _otsuThreshold(img.Image grayscale) {
    final histogram = List.filled(256, 0);
    final total = grayscale.width * grayscale.height;

    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        histogram[img.getLuminance(grayscale.getPixel(x, y)).toInt()]++;
      }
    }

    double sumAll = 0;
    for (int i = 0; i < 256; i++) sumAll += i * histogram[i];

    double sumB = 0;
    int wB = 0;
    double maxVariance = 0;
    int bestThreshold = 128;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;

      sumB += t * histogram[t];
      final meanB = sumB / wB;
      final meanF = (sumAll - sumB) / wF;
      final variance = wB * wF * (meanB - meanF) * (meanB - meanF);

      if (variance > maxVariance) {
        maxVariance = variance;
        bestThreshold = t;
      }
    }
    return bestThreshold;
  }
}
