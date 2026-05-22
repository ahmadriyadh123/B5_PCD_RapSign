import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'roi_extraction_service.dart';
import 'segmentation_service.dart';
import 'normalization_service.dart';

class PreprocessingResult {
  final img.Image originalImage;
  final img.Image croppedDocument;   // Step 1: crop area putih
  final img.Image detectedInk;       // Step 2: area coretan paling bawah
  final img.Image segmentedImage;    // Step 3: segmentasi
  final img.Image normalizedImage;   // Step 4: resize final
  final Uint8List outputBytes;
  
  // Penambahan DTO Koordinat Bounding Box untuk Anggota 4
  final int boundingBoxX;
  final int boundingBoxY;
  final int boundingBoxWidth;
  final int boundingBoxHeight;

  PreprocessingResult({
    required this.originalImage,
    required this.croppedDocument,
    required this.detectedInk,
    required this.segmentedImage,
    required this.normalizedImage,
    required this.outputBytes,
    required this.boundingBoxX,
    required this.boundingBoxY,
    required this.boundingBoxWidth,
    required this.boundingBoxHeight,
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

    // Step 1: Crop dokumen putih (Kini mengembalikan RoiCropResult)
    final docCropResult = _roiService.cropWhiteDocument(original);

    // Step 2: Deteksi coretan paling bawah (Kini menerima dan mengembalikan RoiCropResult)
    final inkCropResult = _roiService.detectInkFromBottom(docCropResult);

    // Step 3: Segmentasi (Diambil dari image hasil crop final)
    final segmented = _segmentationService.adaptiveThreshold(inkCropResult.image);

    // Step 4: Normalisasi ukuran
    final normalized = _normalizationService.resizeWithAspectRatio(segmented, size: targetSize);

    return PreprocessingResult(
      originalImage: original,
      croppedDocument: docCropResult.image,
      detectedInk: inkCropResult.image,
      segmentedImage: segmented,
      normalizedImage: normalized,
      outputBytes: Uint8List.fromList(img.encodePng(normalized)),
      
      // Mengirim koordinat absolut ke Vision Controller
      boundingBoxX: inkCropResult.x,
      boundingBoxY: inkCropResult.y,
      boundingBoxWidth: inkCropResult.width,
      boundingBoxHeight: inkCropResult.height,
    );
  }
}