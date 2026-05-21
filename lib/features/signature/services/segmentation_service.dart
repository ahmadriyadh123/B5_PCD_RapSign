import 'package:image/image.dart' as img;

/// Service untuk segmentasi citra dasar - memisahkan tanda tangan dari background.
/// Menggunakan thresholding dan deteksi kontur sederhana.
class SegmentationService {
  /// Konversi ke grayscale lalu terapkan binary threshold.
  /// Pixel di bawah threshold → hitam (tinta), di atas → putih (background).
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

  /// Adaptive threshold menggunakan mean lokal.
  /// Lebih robust terhadap pencahayaan tidak merata.
  img.Image adaptiveThreshold(img.Image source, {int blockSize = 15, int c = 10}) {
    final grayscale = img.grayscale(source);
    final result = img.Image(width: grayscale.width, height: grayscale.height);
    final half = blockSize ~/ 2;

    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        int sum = 0, count = 0;
        for (int dy = -half; dy <= half; dy++) {
          for (int dx = -half; dx <= half; dx++) {
            final nx = (x + dx).clamp(0, grayscale.width - 1);
            final ny = (y + dy).clamp(0, grayscale.height - 1);
            sum += img.getLuminance(grayscale.getPixel(nx, ny)).toInt();
            count++;
          }
        }
        final mean = sum ~/ count;
        final lum = img.getLuminance(grayscale.getPixel(x, y)).toInt();
        final val = lum < (mean - c) ? 0 : 255;
        result.setPixel(x, y, img.ColorRgb8(val, val, val));
      }
    }
    return result;
  }

  /// Deteksi edge sederhana menggunakan Sobel operator.
  img.Image edgeDetection(img.Image source) {
    final grayscale = img.grayscale(source);
    final result = img.Image(width: grayscale.width, height: grayscale.height);

    for (int y = 1; y < grayscale.height - 1; y++) {
      for (int x = 1; x < grayscale.width - 1; x++) {
        // Sobel kernels
        final gx = -img.getLuminance(grayscale.getPixel(x - 1, y - 1)).toInt() +
            img.getLuminance(grayscale.getPixel(x + 1, y - 1)).toInt() +
            -2 * img.getLuminance(grayscale.getPixel(x - 1, y)).toInt() +
            2 * img.getLuminance(grayscale.getPixel(x + 1, y)).toInt() +
            -img.getLuminance(grayscale.getPixel(x - 1, y + 1)).toInt() +
            img.getLuminance(grayscale.getPixel(x + 1, y + 1)).toInt();

        final gy = -img.getLuminance(grayscale.getPixel(x - 1, y - 1)).toInt() +
            -2 * img.getLuminance(grayscale.getPixel(x, y - 1)).toInt() +
            -img.getLuminance(grayscale.getPixel(x + 1, y - 1)).toInt() +
            img.getLuminance(grayscale.getPixel(x - 1, y + 1)).toInt() +
            2 * img.getLuminance(grayscale.getPixel(x, y + 1)).toInt() +
            img.getLuminance(grayscale.getPixel(x + 1, y + 1)).toInt();

        final magnitude = _sqrt(gx * gx + gy * gy).clamp(0, 255);
        result.setPixel(x, y, img.ColorRgb8(magnitude, magnitude, magnitude));
      }
    }
    return result;
  }

  /// Masking: hapus background dan pertahankan hanya area tanda tangan (foreground).
  /// Menghasilkan gambar dengan background putih bersih.
  img.Image applyMask(img.Image source, img.Image binaryMask) {
    final result = img.Image(width: source.width, height: source.height);
    img.fill(result, color: img.ColorRgb8(255, 255, 255));

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final maskPixel = img.getLuminance(binaryMask.getPixel(x, y)).toInt();
        if (maskPixel == 0) {
          // Foreground (tinta)
          result.setPixel(x, y, source.getPixel(x, y));
        }
      }
    }
    return result;
  }

  int _sqrt(int value) {
    if (value <= 0) return 0;
    int x = value;
    int y = (x + 1) ~/ 2;
    while (y < x) {
      x = y;
      y = (x + value ~/ x) ~/ 2;
    }
    return x;
  }
}
