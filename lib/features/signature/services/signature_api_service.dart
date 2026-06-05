import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Response dari endpoint /verify
class VerificationResponse {
  final bool success;
  final String verificationResult; // "valid" | "invalid"
  final double similarityScore;
  final String predictedLabel;
  final String enrolledLabel;
  final List<int> detectionCoordinate; // [x, y, w, h]
  final Uint8List? contourImageBytes; // PNG bytes untuk ditampilkan
  final double thresholdUsed;
  final String? errorMessage;

  const VerificationResponse({
    required this.success,
    required this.verificationResult,
    required this.similarityScore,
    required this.predictedLabel,
    required this.enrolledLabel,
    required this.detectionCoordinate,
    this.contourImageBytes,
    required this.thresholdUsed,
    this.errorMessage,
  });

  bool get isValid => verificationResult == 'valid';

  factory VerificationResponse.fromJson(Map<String, dynamic> json) {
    Uint8List? contourBytes;
    final b64 = json['contour_image_base64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      contourBytes = base64Decode(b64);
    }

    return VerificationResponse(
      success: json['success'] as bool? ?? false,
      verificationResult: json['verification_result'] as String? ?? 'error',
      similarityScore:
          (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
      predictedLabel: json['predicted_label'] as String? ?? '',
      enrolledLabel: json['enrolled_label'] as String? ?? '',
      detectionCoordinate:
          (json['detection_coordinate'] as List<dynamic>?)
                  ?.map((e) => (e as num).toInt())
                  .toList() ??
              [0, 0, 0, 0],
      contourImageBytes: contourBytes,
      thresholdUsed:
          (json['threshold_used'] as num?)?.toDouble() ?? 0.75,
    );
  }

  factory VerificationResponse.error(String message) {
    return VerificationResponse(
      success: false,
      verificationResult: 'error',
      similarityScore: 0.0,
      predictedLabel: '',
      enrolledLabel: '',
      detectionCoordinate: [0, 0, 0, 0],
      thresholdUsed: 0.75,
      errorMessage: message,
    );
  }
}

/// Response dari endpoint /health
class ServerHealthResponse {
  final bool isOnline;
  final bool modelReady;
  final List<String> enrolledLabels;

  const ServerHealthResponse({
    required this.isOnline,
    required this.modelReady,
    required this.enrolledLabels,
  });

  factory ServerHealthResponse.offline() => const ServerHealthResponse(
        isOnline: false,
        modelReady: false,
        enrolledLabels: [],
      );
}

/// Service untuk komunikasi HTTP dengan FastAPI server
class SignatureApiService {
  // Ganti IP ini sesuai IP komputer di jaringan yang sama saat testing di device
  // Untuk emulator Android: gunakan 10.0.2.2
  // Untuk device fisik: gunakan IP lokal komputer (misal 192.168.1.x)
  static const String _baseUrl = 'http://192.168.137.62:8000';

  static final SignatureApiService _instance = SignatureApiService._internal();
  factory SignatureApiService() => _instance;
  SignatureApiService._internal();

  final http.Client _client = http.Client();

  /// Cek status server dan model
  Future<ServerHealthResponse> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ServerHealthResponse(
          isOnline: true,
          modelReady: json['model_ready'] as bool? ?? false,
          enrolledLabels: (json['enrolled_labels'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
        );
      }
      return ServerHealthResponse.offline();
    } catch (_) {
      return ServerHealthResponse.offline();
    }
  }

  /// Kirim gambar ke server untuk diverifikasi
  ///
  /// [imageBytes] — bytes gambar mentah (JPEG/PNG)
  /// [enrolledLabel] — label pemilik ttd yang diklaim (opsional)
  /// [threshold] — threshold kemiripan (default 0.75)
  Future<VerificationResponse> verifySignature({
    required Uint8List imageBytes,
    String? enrolledLabel,
    double threshold = 0.75,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/verify');
      final request = http.MultipartRequest('POST', uri);

      // Tambah file gambar
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'signature.jpg',
        ),
      );

      // Tambah field opsional
      if (enrolledLabel != null && enrolledLabel.isNotEmpty) {
        request.fields['enrolled_label'] = enrolledLabel;
      }
      request.fields['threshold'] = threshold.toString();

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return VerificationResponse.fromJson(json);
      }

      // Error dari server
      String errorMsg = 'Server error (${response.statusCode})';
      try {
        final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
        errorMsg = errorJson['detail'] as String? ?? errorMsg;
      } catch (_) {}

      return VerificationResponse.error(errorMsg);
    } on Exception catch (e) {
      return VerificationResponse.error(
        'Tidak dapat menghubungi server. Pastikan server berjalan.\n$e',
      );
    }
  }

  /// Preview kontur gambar tanpa verifikasi (untuk debugging)
  Future<Uint8List?> previewContour(Uint8List imageBytes) async {
    try {
      final uri = Uri.parse('$_baseUrl/enroll/preview');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: 'img.jpg'),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final b64 = json['contour_image_base64'] as String?;
        if (b64 != null) return base64Decode(b64);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}