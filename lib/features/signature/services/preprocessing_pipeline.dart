import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'roi_extraction_service.dart';
import 'segmentation_service.dart';
import 'normalization_service.dart';

/// Hasil dari preprocessing pipeline — setiap step untuk debugging.
class PreprocessingResult {
  final img.Image originalImage;
  final img.Image croppedDocument;   // Step 1: crop area putih
  final img.Image detectedInk;       // Step 2: area coretan paling bawah
  final img.Image segmentedImage;    // Step 3: segmentasi
  final img.Image normalizedImage;   // Step 4: resize final
  final Uint8List outputBytes;

  PreprocessingResult({
    required this.originalImage,
    required this.croppedDocument,
    required this.detectedInk,
    required this.segmentedImage,
    required this.normalizedImage,
    required this.outputBytes,
  });
}

/// Pipeline: Crop Document → Detect Ink dari Bawah → Segmentasi → Normalisasi
class PreprocessingPipeline {
  final RoiExtractionService _roiService = RoiExtractionService();
  final SegmentationService _segmentationService = SegmentationService();
  final NormalizationService _normalizationService = NormalizationService();

  Future<PreprocessingResult> process(Uint8List imageBytes, {int targetSize = 256}) async {
    final original = img.decodeImage(imageBytes);
    if (original == null) throw Exception('Gagal decode gambar');

    // Step 1: Crop dokumen putih
    final croppedDoc = _roiService.cropWhiteDocument(original);

    // Step 2: Deteksi coretan paling bawah
    final ink = _roiService.detectInkFromBottom(croppedDoc);

    // Step 3: Segmentasi
    final segmented = _segmentationService.adaptiveThreshold(ink);

    // Step 4: Normalisasi ukuran
    final normalized = _normalizationService.resizeWithAspectRatio(segmented, size: targetSize);

    return PreprocessingResult(
      originalImage: original,
      croppedDocument: croppedDoc,
      detectedInk: ink,
      segmentedImage: segmented,
      normalizedImage: normalized,
      outputBytes: Uint8List.fromList(img.encodePng(normalized)),
    );
  }
}
