import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'roi_extraction_service.dart';
import 'segmentation_service.dart';
import 'normalization_service.dart';

/// Hasil dari preprocessing pipeline.
class PreprocessingResult {
  final img.Image originalImage;
  final img.Image roiImage;
  final img.Image segmentedImage;
  final img.Image normalizedImage;
  final Uint8List outputBytes;

  PreprocessingResult({
    required this.originalImage,
    required this.roiImage,
    required this.segmentedImage,
    required this.normalizedImage,
    required this.outputBytes,
  });
}

/// Pipeline yang mengorkestrasi seluruh tahap preprocessing:
/// 1. ROI Extraction → 2. Segmentation → 3. Normalization
class PreprocessingPipeline {
  final RoiExtractionService _roiService = RoiExtractionService();
  final SegmentationService _segmentationService = SegmentationService();
  final NormalizationService _normalizationService = NormalizationService();

  /// Jalankan pipeline lengkap dari bytes gambar mentah.
  Future<PreprocessingResult> process(Uint8List imageBytes, {int targetSize = 256}) async {
    final original = img.decodeImage(imageBytes);
    if (original == null) throw Exception('Gagal decode gambar');

    // Step 1: ROI Extraction
    final roi = _roiService.extractFromDocument(original);

    // Step 2: Segmentation (adaptive threshold untuk handle pencahayaan tidak merata)
    final segmented = _segmentationService.adaptiveThreshold(roi);

    // Step 3: Normalization (resize dengan aspek rasio + contrast stretching)
    final resized = _normalizationService.resizeWithAspectRatio(segmented, size: targetSize);
    final normalized = _normalizationService.normalizeIntensity(resized);

    return PreprocessingResult(
      originalImage: original,
      roiImage: roi,
      segmentedImage: segmented,
      normalizedImage: normalized,
      outputBytes: Uint8List.fromList(img.encodePng(normalized)),
    );
  }

  /// Proses hanya dari tahap ROI (jika gambar sudah di-crop manual).
  img.Image processFromRoi(img.Image roiImage, {int targetSize = 256}) {
    final segmented = _segmentationService.adaptiveThreshold(roiImage);
    final resized = _normalizationService.resizeWithAspectRatio(segmented, size: targetSize);
    return _normalizationService.normalizeIntensity(resized);
  }
}
