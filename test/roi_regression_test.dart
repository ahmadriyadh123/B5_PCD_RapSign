import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:logbook_app_001/features/signature/services/roi_extraction_service.dart';

class _Box {
  final int x;
  final int y;
  final int width;
  final int height;

  const _Box(this.x, this.y, this.width, this.height);

  factory _Box.fromJson(List<dynamic> values) {
    return _Box(
      values[0] as int,
      values[1] as int,
      values[2] as int,
      values[3] as int,
    );
  }

  int get right => x + width;
  int get bottom => y + height;
}

double _iou(_Box a, _Box b) {
  final left = a.x > b.x ? a.x : b.x;
  final top = a.y > b.y ? a.y : b.y;
  final right = a.right < b.right ? a.right : b.right;
  final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;

  if (right <= left || bottom <= top) {
    return 0.0;
  }

  final intersection = (right - left) * (bottom - top);
  final union = a.width * a.height + b.width * b.height - intersection;
  return union == 0 ? 0.0 : intersection / union;
}

void main() {
  test('ROI regression matches Python golden boxes', () async {
    final roiService = RoiExtractionService();
    final pythonResultsFile = File('python_outputs/roi_validation/results.json');
    final samplesRoot = Directory('python_outputs/dummy_other_group/contour');

    final pythonResults = jsonDecode(await pythonResultsFile.readAsString()) as Map<String, dynamic>;

    final classDirs = samplesRoot
        .listSync()
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final ious = <double>[];

    for (final classDir in classDirs) {
      final label = classDir.path.split(Platform.pathSeparator).last;
      final goldenClass = (pythonResults[label] as Map<String, dynamic>?) ?? {};

      final imageFiles = classDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final imageFile in imageFiles) {
        final bytes = await imageFile.readAsBytes();
        final decoded = img.decodeImage(bytes);
        expect(decoded, isNotNull, reason: 'Failed to decode ${imageFile.path}');

        final result = roiService.detectInkFromImage(decoded!);
        final fileName = imageFile.uri.pathSegments.last;
        final golden = goldenClass[fileName] as List<dynamic>?;
        expect(golden, isNotNull, reason: 'Missing golden box for $label/$fileName');

        final expected = _Box.fromJson(golden!);
        final actual = _Box(result.x, result.y, result.width, result.height);
        final score = _iou(actual, expected);
        ious.add(score);

        expect(
          score,
          greaterThanOrEqualTo(0.98),
          reason: '$label/$fileName mismatch: actual=[${actual.x}, ${actual.y}, ${actual.width}, ${actual.height}] expected=[${expected.x}, ${expected.y}, ${expected.width}, ${expected.height}]',
        );
      }
    }

    final meanIou = ious.reduce((a, b) => a + b) / ious.length;
    expect(meanIou, greaterThanOrEqualTo(0.99));
  });
}
