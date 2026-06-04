import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Lightweight inference HTTP client with timeout and retry support.
///
/// You can inject a custom `http.Client` for testing or provide a
/// different `baseUrl` for production by passing `baseUrl`.

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
  final http.Client _client;
  final Duration timeout;
  final int maxRetries;

  InferenceService({
    String baseUrl = 'http://127.0.0.1:8000',
    http.Client? client,
    Duration? timeout,
    int maxRetries = 1,
  })  : baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client(),
        timeout = timeout ?? const Duration(seconds: 10),
        maxRetries = maxRetries;

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
    final url = Uri.parse('${baseUri.toString().replaceAll(RegExp(r'/$'), '')}/infer');

    // Build multipart request
    final request = http.MultipartRequest('POST', url);
    request.fields['threshold'] = threshold.toString();
    if (enrolledLabel != null) request.fields['enrolled_label'] = enrolledLabel;
    request.files.add(http.MultipartFile.fromBytes('contour', contourBytes,
        filename: 'contour.png', contentType: MediaType('image', 'png')));
    request.files.add(http.MultipartFile.fromBytes('feature_ready', featureReadyBytes,
        filename: 'feature_ready.png', contentType: MediaType('image', 'png')));

    int attempt = 0;
    while (true) {
      attempt += 1;
      try {
        final streamed = await _client.send(request).timeout(timeout);
        final resp = await http.Response.fromStream(streamed).timeout(timeout);
        if (resp.statusCode != 200) {
          throw Exception('Inference server returned ${resp.statusCode}: ${resp.body}');
        }
        final parsed = jsonDecode(resp.body) as Map<String, dynamic>;
        return InferenceResult.fromJson(parsed);
      } catch (e) {
        if (attempt >= maxRetries) {
          rethrow;
        }
        // exponential backoff before retrying
        final backoff = Duration(milliseconds: 200 * (1 << (attempt - 1)));
        await Future.delayed(backoff);
      }
    }
  }
}
