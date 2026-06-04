import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/vision/vision_controller.dart';
import 'package:logbook_app_001/features/signature/services/inference_service.dart';

class MockInferenceService extends InferenceService {
  MockInferenceService(): super();

  @override
  Future<InferenceResult> infer({
    required Uint8List contourBytes,
    required Uint8List featureReadyBytes,
    String? enrolledLabel,
    double threshold = 0.75,
  }) async {
    // return a deterministic fake response
    return InferenceResult(valid: true, similarity: 0.92, verdict: 'valid', raw: {'mock': true});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('VisionController uses InferenceService and updates score/state', () async {
    // load a sample image from repo to simulate captured frame
    final sample = File('python_outputs/dummy_other_group/contour/a_(101)/1.png');
    expect(await sample.exists(), true, reason: 'sample image must exist in repo');
    final bytes = await sample.readAsBytes();

    final mock = MockInferenceService();
    final controller = VisionController(inferenceService: mock);

    // set captured bytes and run processing
    controller.capturedImageBytes = bytes;

    await controller.processCapturedFrame();

    // After processing, controller should have used mock result
    expect(controller.similarityScore, closeTo(0.92, 1e-6));
    expect(controller.isSignatureValid, isTrue);
  });
}
