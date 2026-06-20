import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:logbook_app_001/features/signature/services/preprocessing_pipeline.dart';
import 'package:logbook_app_001/features/signature/services/roi_extraction_service.dart';

void main() {
  test('compare Flutter ROI output with python validation samples', () async {
    final pipeline = PreprocessingPipeline();
    final roiService = RoiExtractionService();
    final sampleRoot = Directory('python_outputs/dummy_other_group/contour');
    final pythonResultsFile = File('python_outputs/roi_validation/results.json');
    final pythonResults = jsonDecode(await pythonResultsFile.readAsString()) as Map<String, dynamic>;

    final classDirs = sampleRoot.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final classDir in classDirs) {
      final label = classDir.path.split(Platform.pathSeparator).last;
      final imageFiles = classDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final pythonClass = (pythonResults[label] as Map<String, dynamic>?) ?? {};

      for (final imageFile in imageFiles) {
        final bytes = await imageFile.readAsBytes();
        final result = await pipeline.process(bytes);
        final decoded = img.decodeImage(bytes);
        final inkOnly = decoded == null ? null : roiService.detectInkFromImage(decoded);
        final fileName = imageFile.uri.pathSegments.last;
        final pythonBox = pythonClass[fileName];
        // The print output is used to compare the full pipeline versus the ink-only path.
        // ignore: avoid_print
        print(
          '$label/$fileName | full=[${result.boundingBoxX}, ${result.boundingBoxY}, ${result.boundingBoxWidth}, ${result.boundingBoxHeight}] | inkOnly=${inkOnly == null ? 'decode_error' : '[${inkOnly.x}, ${inkOnly.y}, ${inkOnly.width}, ${inkOnly.height}]'} | python=$pythonBox',
        );
      }
    }
  });
}