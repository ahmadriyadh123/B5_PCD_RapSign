import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../signature/models/verification_log_model.dart';
import '../signature/services/signature_api_service.dart';
import '../signature/services/verification_mongo_service.dart';

enum SignatureVerificationState {
  idle,           // menunggu input
  capturing,      // sedang capture dari kamera
  processing,     // mengirim ke server & menunggu hasil
  result,         // menampilkan hasil
  error,          // error
}

class SignatureVerificationController extends ChangeNotifier {
  // ─── State ──────────────────────────────────────────────────
  SignatureVerificationState _state = SignatureVerificationState.idle;
  CameraController? cameraController;
  bool isCameraInitialized = false;
  String? errorMessage;

  VerificationResponse? lastResult;
  Uint8List? capturedImageBytes;
  String? selectedLabel;
  List<String> availableLabels = [];
  bool isServerOnline = false;
  bool isLoadingLabels = true;

  final String username;
  late Box<VerificationLogModel> _box;
  bool _isDisposed = false;

  SignatureVerificationState get state => _state;
  bool get isProcessing =>
      _state == SignatureVerificationState.processing ||
      _state == SignatureVerificationState.capturing;

  SignatureVerificationController({required this.username});

  // ─── Init ────────────────────────────────────────────────────
  Future<void> init() async {
    _box = await Hive.openBox<VerificationLogModel>('verification_logs');
    await _checkServerAndLabels();
    await _initCamera();
  }

  Future<void> _checkServerAndLabels() async {
    isLoadingLabels = true;
    _notify();

    final health = await SignatureApiService().checkHealth();
    isServerOnline = health.isOnline && health.modelReady;
    availableLabels = health.enrolledLabels;
    if (availableLabels.isNotEmpty) {
      selectedLabel = availableLabels.first;
    }

    isLoadingLabels = false;
    _notify();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _setError('Izin kamera ditolak. Aktifkan di pengaturan.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setError('Tidak ada kamera yang tersedia di perangkat ini.');
        return;
      }

      cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await cameraController!.initialize();
      isCameraInitialized = true;
      _notify();
    } catch (e) {
      _setError('Gagal inisialisasi kamera: $e');
    }
  }

  // ─── Actions ─────────────────────────────────────────────────

  /// Capture frame dari kamera live, langsung verifikasi
  Future<void> captureAndVerify() async {
    if (!isCameraInitialized || cameraController == null) return;
    if (_state == SignatureVerificationState.processing) return;

    _setState(SignatureVerificationState.capturing);

    try {
      final xFile = await cameraController!.takePicture();
      capturedImageBytes = await xFile.readAsBytes();
      await _sendForVerification();
    } catch (e) {
      _setError('Gagal mengambil gambar: $e');
    }
  }

  /// Pilih gambar dari galeri, lalu verifikasi
  Future<void> pickFromGallery() async {
    if (_state == SignatureVerificationState.processing) return;

    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (xFile == null) return;

      capturedImageBytes = await xFile.readAsBytes();
      _setState(SignatureVerificationState.capturing);
      await _sendForVerification();
    } catch (e) {
      _setError('Gagal memilih gambar: $e');
    }
  }

  Future<void> _sendForVerification() async {
    if (capturedImageBytes == null) return;
    _setState(SignatureVerificationState.processing);

    final response = await SignatureApiService().verifySignature(
      imageBytes: capturedImageBytes!,
      enrolledLabel: selectedLabel,
    );

    lastResult = response;

    if (response.success) {
      // Simpan ke local Hive dulu
      final logEntry = VerificationLogModel.fromJson(
        {
          'verification_result': response.verificationResult,
          'similarity_score': response.similarityScore,
          'predicted_label': response.predictedLabel,
          'enrolled_label': response.enrolledLabel,
        },
        verifiedBy: username,
      );
      await _box.add(logEntry);

      // Sync ke MongoDB Atlas di background
      _syncToCloud(logEntry);
      _setState(SignatureVerificationState.result);
    } else {
      _setError(response.errorMessage ?? 'Verifikasi gagal.');
    }
  }

  Future<void> _syncToCloud(VerificationLogModel log) async {
    try {
      await VerificationMongoService().connect();
      await VerificationMongoService().insertLog(log);

      // Update isSynced di Hive
      final idx = _box.values.toList().indexWhere((l) => l.id != null && l.id == log.id);
      if (idx != -1) {
        await _box.putAt(idx, log.copyWith(isSynced: true));
      }
    } catch (_) {
      // Gagal sync ke cloud — tetap tersimpan lokal
    }
  }

  void setSelectedLabel(String? label) {
    selectedLabel = label;
    _notify();
  }

  /// Reset ke state idle untuk verifikasi baru
  void reset() {
    capturedImageBytes = null;
    lastResult = null;
    errorMessage = null;
    _setState(SignatureVerificationState.idle);
  }

  void retryServerCheck() {
    _checkServerAndLabels();
  }

  // ─── Helpers ─────────────────────────────────────────────────
  void _setState(SignatureVerificationState s) {
    _state = s;
    errorMessage = null;
    _notify();
  }

  void _setError(String msg) {
    errorMessage = msg;
    _state = SignatureVerificationState.error;
    _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    cameraController?.dispose();
    super.dispose();
  }
}