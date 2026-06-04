import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class InferenceResult {
  final bool valid;
  final double similarity;
  final String verdict;
  final Map<String, dynamic> raw;

  InferenceResult({required this.valid, required this.similarity, required this.verdict, required this.raw});

  factory InferenceResult.fromJson(Map<String, dynamic> j) {
    return InferenceResult(
      valid: j['result'] == 'valid' || j['valid'] == true,
      similarity: (j['similarity'] as num?)?.toDouble() ?? 0.0,
      verdict: j['result'] ?? (j['verdict'] ?? ''),
      raw: j,
    );
  }
}

class InferenceService {
  final Uri baseUri;

  InferenceService({String baseUrl = 'http://127.0.0.1:8000'}) : baseUri = Uri.parse(baseUrl);

  /// Calls POST /infer with multipart form:
  /// - contour: file
  /// - feature_ready: file
  /// - enrolled_label: optional
  /// Returns [InferenceResult].
  Future<InferenceResult> infer({
    required Uint8List contourBytes,
    required Uint8List featureReadyBytes,
    String? enrolledLabel,
    double threshold = 0.75,
  }) async {
    final url = baseUri.replace(path: '${baseUri.path}/infer');
    final request = http.MultipartRequest('POST', url);
    request.fields['threshold'] = threshold.toString();
    if (enrolledLabel != null) request.fields['enrolled_label'] = enrolledLabel;

    request.files.add(http.MultipartFile.fromBytes('contour', contourBytes, filename: 'contour.png', contentType: MediaType('image', 'png')));
    request.files.add(http.MultipartFile.fromBytes('feature_ready', featureReadyBytes, filename: 'feature_ready.png', contentType: MediaType('image', 'png')));

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('Inference server returned ${resp.statusCode}: ${resp.body}');
    }
    final parsed = jsonDecode(resp.body) as Map<String, dynamic>;
    return InferenceResult.fromJson(parsed);
  }
}
