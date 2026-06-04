import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/vision/vision_controller.dart';
import 'package:logbook_app_001/features/signature/services/inference_service.dart';

class MockInferenceService extends InferenceService {
  MockInferenceService() : super();

  @override
  Future<InferenceResult> infer({
    required Uint8List contourBytes,
    required Uint8List featureReadyBytes,
    String? enrolledLabel,
    double threshold = 0.75,
  }) async {
    // simulate slight network latency
    await Future.delayed(const Duration(milliseconds: 50));
    return InferenceResult(valid: true, similarity: 0.90, verdict: 'valid', raw: {'mock': true});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('E2E pipeline: preprocessing -> inference (mock or real)', () async {
    // choose between real server and mock via env var
    final runReal = Platform.environment['RUN_REAL_E2E'] == '1';

    final sample = File('python_outputs/dummy_other_group/contour/a_(101)/1.png');
    expect(await sample.exists(), true, reason: 'sample image must exist in repo');
    final bytes = await sample.readAsBytes();

    final InferenceService inference;
    if (runReal) {
      final base = Platform.environment['INFER_BASE_URL'] ?? 'http://127.0.0.1:8000';
      inference = InferenceService(baseUrl: base, timeout: const Duration(seconds: 6), maxRetries: 2);
    } else {
      inference = MockInferenceService();
    }

    final controller = VisionController(inferenceService: inference);
    controller.capturedImageBytes = bytes;

    await controller.processCapturedFrame();

    expect(controller.processedImageBytes, isNotNull);
    expect(controller.isProcessing, isFalse);
    // If mock, we expect a positive similarity and valid verdict
    if (!runReal) {
      expect(controller.similarityScore, greaterThan(0.0));
      expect(controller.isSignatureValid, isTrue);
    }
  }, timeout: Timeout(Duration(seconds: 20)));
}
