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

class _PixelPos {
  final int x;
  final int y;

  _PixelPos(this.x, this.y);
}

class _Bounds {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const _Bounds({required this.left, required this.top, required this.right, required this.bottom});

  int get width => right - left + 1;
  int get height => bottom - top + 1;
}

/// Service untuk ekstraksi Region of Interest (ROI) tanda tangan.
class RoiExtractionService {
  static const int _whiteThreshold = 180;
  static const double _rowWhiteRatio = 0.5;
  static const int _morphKernelSize = 3;
  static const int _openIterations = 1;
  static const int _closeIterations = 1;
  static const int _minComponentArea = 20;

  /// Pipeline: crop dokumen → deteksi coretan dengan contour-like thresholding.
  RoiCropResult extractFromDocument(img.Image source) {
    final docCrop = cropWhiteDocument(source);
    return detectInkFromBottom(docCrop);
  }

  /// Jalur pembanding untuk gambar yang sudah berupa crop dokumen/contour.
  /// Ini melewati langkah crop dokumen agar bisa dibandingkan langsung dengan output Python.
  RoiCropResult detectInkFromImage(img.Image source) {
    return detectInkFromBottom(
      RoiCropResult(image: source, x: 0, y: 0, width: source.width, height: source.height),
    );
  }

  /// Crop area dokumen putih dari frame.
  RoiCropResult cropWhiteDocument(img.Image source) {
    final w = source.width;
    final h = source.height;
    final minWhitePerRow = (w * _rowWhiteRatio).toInt();

    int bestStart = 0;
    int bestEnd = h - 1;
    int bestLen = 0;
    int start = -1;

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
    int startX = 0;
    int endX = w - 1;

    for (int x = 0; x < w; x++) {
      if (colWhite[x] >= minPerCol) {
        startX = x;
        break;
      }
    }
    for (int x = w - 1; x >= 0; x--) {
      if (colWhite[x] >= minPerCol) {
        endX = x;
        break;
      }
    }

    final cropW = endX - startX + 1;
    if (cropW < 50 || docH < 50) {
      return RoiCropResult(image: source, x: 0, y: 0, width: w, height: h);
    }

    final cropped = img.copyCrop(source, x: startX, y: bestStart, width: cropW, height: docH);
    return RoiCropResult(image: cropped, x: startX, y: bestStart, width: cropW, height: docH);
  }

  /// Deteksi bounding box tanda tangan dengan thresholding ala Python.
  RoiCropResult detectInkFromBottom(RoiCropResult docCrop) {
    final source = docCrop.image;
    final bounds = _detectInkBounds(source);
    if (bounds == null) {
      return docCrop;
    }

    final cropped = img.copyCrop(
      source,
      x: bounds.left,
      y: bounds.top,
      width: bounds.width,
      height: bounds.height,
    );

    return RoiCropResult(
      image: cropped,
      x: docCrop.x + bounds.left,
      y: docCrop.y + bounds.top,
      width: bounds.width,
      height: bounds.height,
    );
  }

  _Bounds? _detectInkBounds(img.Image source) {
    final grayscale = _toLumaMatrix(source);
    final blurred = _gaussianBlur5x5(grayscale);
    final threshold = _otsuThresholdValues(blurred);
    final mask = _buildInkMaskFromValues(blurred, threshold);
    final cleanedMask = _applyMorphology(mask);
    return _largestComponentBounds(cleanedMask);
  }

  List<List<int>> _toLumaMatrix(img.Image source) {
    final w = source.width;
    final h = source.height;
    return List.generate(h, (y) {
      return List.generate(w, (x) => img.getLuminance(source.getPixel(x, y)).toInt());
    });
  }

  List<List<int>> _gaussianBlur5x5(List<List<int>> values) {
    final h = values.length;
    if (h == 0) return values;
    final w = values.first.length;
    const kernel = [1, 4, 6, 4, 1];
    final result = List.generate(h, (_) => List.filled(w, 0));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double sum = 0;
        for (int ky = 0; ky < 5; ky++) {
          for (int kx = 0; kx < 5; kx++) {
            final ny = _reflectIndex(y + ky - 2, h);
            final nx = _reflectIndex(x + kx - 2, w);
            sum += values[ny][nx] * kernel[ky] * kernel[kx];
          }
        }
        result[y][x] = (sum / 256.0).round();
      }
    }

    return result;
  }

  List<List<bool>> _buildInkMaskFromValues(List<List<int>> grayscale, int threshold) {
    final w = grayscale.first.length;
    final h = grayscale.length;
    final mask = List.generate(h, (_) => List.filled(w, false));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        mask[y][x] = grayscale[y][x] < threshold;
      }
    }

    return mask;
  }

  List<List<bool>> _applyMorphology(List<List<bool>> mask) {
    var processed = mask;

    for (int i = 0; i < _openIterations; i++) {
      processed = _erodeMask(processed);
    }
    for (int i = 0; i < _openIterations; i++) {
      processed = _dilateMask(processed);
    }

    for (int i = 0; i < _closeIterations; i++) {
      processed = _dilateMask(processed);
    }
    for (int i = 0; i < _closeIterations; i++) {
      processed = _erodeMask(processed);
    }

    return processed;
  }

  List<List<bool>> _erodeMask(List<List<bool>> mask) {
    final h = mask.length;
    if (h == 0) return mask;
    final w = mask.first.length;
    final result = List.generate(h, (_) => List.filled(w, false));
    final radius = _morphKernelSize ~/ 2;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        bool keep = true;
        for (int dy = -radius; dy <= radius && keep; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final ny = _reflectIndex(y + dy, h);
            final nx = _reflectIndex(x + dx, w);
            if (!mask[ny][nx]) {
              keep = false;
              break;
            }
          }
        }
        result[y][x] = keep;
      }
    }

    return result;
  }

  List<List<bool>> _dilateMask(List<List<bool>> mask) {
    final h = mask.length;
    if (h == 0) return mask;
    final w = mask.first.length;
    final result = List.generate(h, (_) => List.filled(w, false));
    final radius = _morphKernelSize ~/ 2;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        bool found = false;
        for (int dy = -radius; dy <= radius && !found; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final ny = _reflectIndex(y + dy, h);
            final nx = _reflectIndex(x + dx, w);
            if (mask[ny][nx]) {
              found = true;
              break;
            }
          }
        }
        result[y][x] = found;
      }
    }

    return result;
  }

  int _reflectIndex(int index, int length) {
    if (length <= 1) return 0;
    var value = index;
    while (value < 0 || value >= length) {
      if (value < 0) {
        value = -value - 1;
      } else {
        value = (length * 2) - value - 1;
      }
    }
    return value;
  }

  _Bounds? _largestComponentBounds(List<List<bool>> mask) {
    final h = mask.length;
    if (h == 0) return null;
    final w = mask.first.length;
    final visited = List.generate(h, (_) => List.filled(w, false));

    _Bounds? bestBounds;
    int bestScore = 0;
    final stack = <_PixelPos>[];

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (!mask[y][x] || visited[y][x]) continue;

        int left = x;
        int right = x;
        int top = y;
        int bottom = y;
        int area = 0;

        stack.add(_PixelPos(x, y));
        visited[y][x] = true;

        while (stack.isNotEmpty) {
          final current = stack.removeLast();
          area++;
          if (current.x < left) left = current.x;
          if (current.x > right) right = current.x;
          if (current.y < top) top = current.y;
          if (current.y > bottom) bottom = current.y;

          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nx = current.x + dx;
              final ny = current.y + dy;
              if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
              if (visited[ny][nx] || !mask[ny][nx]) continue;
              visited[ny][nx] = true;
              stack.add(_PixelPos(nx, ny));
            }
          }
        }

        if (area < _minComponentArea) {
          continue;
        }

        if (area > bestScore) {
          bestScore = area;
          bestBounds = _Bounds(left: left, top: top, right: right, bottom: bottom);
        }
      }
    }

    return bestBounds;
  }

  int _otsuThresholdValues(List<List<int>> grayscale) {
    final histogram = List.filled(256, 0);
    final total = grayscale.length * grayscale.first.length;

    for (int y = 0; y < grayscale.length; y++) {
      for (int x = 0; x < grayscale.first.length; x++) {
        histogram[grayscale[y][x]]++;
      }
    }

    double sumAll = 0;
    for (int i = 0; i < 256; i++) {
      sumAll += i * histogram[i];
    }

    double sumB = 0;
    int weightB = 0;
    double maxVariance = 0;
    int bestThreshold = 128;

    for (int t = 0; t < 256; t++) {
      weightB += histogram[t];
      if (weightB == 0) continue;

      final weightF = total - weightB;
      if (weightF == 0) break;

      sumB += t * histogram[t];
      final meanB = sumB / weightB;
      final meanF = (sumAll - sumB) / weightF;
      final variance = weightB * weightF * (meanB - meanF) * (meanB - meanF);

      if (variance > maxVariance) {
        maxVariance = variance;
        bestThreshold = t;
      }
    }

    return bestThreshold;
  }
}
