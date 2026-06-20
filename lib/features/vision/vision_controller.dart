import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../signature/services/preprocessing_pipeline.dart';
import 'vision_image_processor.dart';
import '../signature/services/inference_service.dart';
import 'package:image/image.dart' as img_lib;
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum VisionInteractiveFilterId {
  natural,
  contrastBoost,
  brightPop,
  histogramFocus,
  blurSoft,
  sharpenPlus,
  edgeDetect,
}

class VisionInteractiveFilter {
  const VisionInteractiveFilter({
    required this.id,
    required this.label,
    required this.filterType,
    required this.filterIntensity,
    required this.applyContrast,
    required this.customContrast,
    required this.customBrightness,
    required this.customSaturation,
    required this.showHistogram,
  });

  final VisionInteractiveFilterId id;
  final String label;
  final VisionFilterType filterType;
  final double filterIntensity;
  final bool applyContrast;
  final double customContrast;
  final double customBrightness;
  final double customSaturation;
  final bool showHistogram;
}

const List<VisionInteractiveFilter> visionInteractiveFilters = [
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.natural,
    label: 'Natural',
    filterType: VisionFilterType.none,
    filterIntensity: 0.0,
    applyContrast: false,
    customContrast: 1.0,
    customBrightness: 0.0,
    customSaturation: 1.0,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.contrastBoost,
    label: 'Contrast+',
    filterType: VisionFilterType.none,
    filterIntensity: 0.55,
    applyContrast: true,
    customContrast: 1.2,
    customBrightness: 0.0,
    customSaturation: 1.05,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.brightPop,
    label: 'Bright Pop',
    filterType: VisionFilterType.none,
    filterIntensity: 0.7,
    applyContrast: true,
    customContrast: 1.08,
    customBrightness: 0.08,
    customSaturation: 1.08,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.histogramFocus,
    label: 'Histogram',
    filterType: VisionFilterType.none,
    filterIntensity: 0.68,
    applyContrast: true,
    customContrast: 1.16,
    customBrightness: 0.0,
    customSaturation: 0.95,
    showHistogram: true,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.blurSoft,
    label: 'Blur',
    filterType: VisionFilterType.blur,
    filterIntensity: 0.72,
    applyContrast: false,
    customContrast: 1.0,
    customBrightness: 0.0,
    customSaturation: 1.0,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.sharpenPlus,
    label: 'Sharpen',
    filterType: VisionFilterType.sharpen,
    filterIntensity: 0.88,
    applyContrast: true,
    customContrast: 1.12,
    customBrightness: -0.01,
    customSaturation: 1.03,
    showHistogram: false,
  ),
  VisionInteractiveFilter(
    id: VisionInteractiveFilterId.edgeDetect,
    label: 'Edge',
    filterType: VisionFilterType.edgeDetection,
    filterIntensity: 0.8,
    applyContrast: true,
    customContrast: 1.26,
    customBrightness: -0.02,
    customSaturation: 0.88,
    showHistogram: true,
  ),
];

class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? controller;
  bool isInitialized = false;
  String? errorMessage;
  bool isTorchEnabled = false;
  bool isOverlayEnabled = true;
  bool isLoading = false;
  String loadingMessage = 'Menghubungkan ke Sensor Visual...';
  bool isCapturing = false;
  bool isProcessing = false;
  String? processMessage;
  VisionFilterType selectedFilter = VisionFilterType.none;
  VisionPresetStyle selectedPreset = VisionPresetStyle.original;
  bool applyContrast = true;
  bool showHistogram = true;
  double filterIntensity = 0.8;
  double customContrast = 1.0;
  double customBrightness = 0.0;
  double customSaturation = 1.0;
  VisionInteractiveFilterId selectedInteractiveFilter =
      VisionInteractiveFilterId.natural;
  Map<VisionInteractiveFilterId, Uint8List> filterPreviewBytes =
      const <VisionInteractiveFilterId, Uint8List>{};
  bool isGeneratingFilterPreviews = false;

  Uint8List? capturedImageBytes;
  Uint8List? processedImageBytes;
  List<int>? histogramBins;

  Timer? _processDebounceTimer;
  bool _isInitializing = false;
  bool _isDisposed = false;
  int _previewGenerationToken = 0;
  final InferenceService? inferenceService;

  // ─── STATE REAL-TIME PIPELINE TANDA TANGAN ───────────────────
  Rect? _signatureBoundingBox;
  double _similarityScore = 0.0;
  bool _isSignatureValid = false;

  Rect? get signatureBoundingBox => _signatureBoundingBox;
  double get similarityScore => _similarityScore;
  bool get isSignatureValid => _isSignatureValid;

  bool get hasCapturedImage => capturedImageBytes != null;
  List<VisionInteractiveFilter> get availableInteractiveFilters =>
      visionInteractiveFilters;

  // --- Mock / Overlay helpers (used by DamagePainter overlay)
  /// Normalized detection center (0..1) relative to preview frame.
  Offset get mockDetectionCenter {
    if (_signatureBoundingBox != null && controller?.value.previewSize != null) {
      final preview = controller!.value.previewSize!;
      // previewSize from camera may be rotated; use width/height as provided
      final centerX = _signatureBoundingBox!.left + _signatureBoundingBox!.width / 2;
      final centerY = _signatureBoundingBox!.top + _signatureBoundingBox!.height / 2;
      final nx = preview.width > 0 ? (centerX / preview.width) : 0.5;
      final ny = preview.height > 0 ? (centerY / preview.height) : 0.5;
      return Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
    }
    return const Offset(0.5, 0.5);
  }

  /// Width ratio for detection box (0..1)
  double get mockDetectionWidthRatio {
    if (_signatureBoundingBox != null && controller?.value.previewSize != null) {
      final preview = controller!.value.previewSize!;
      final ratio = preview.width > 0 ? (_signatureBoundingBox!.width / preview.width) : 0.28;
      return ratio.clamp(0.05, 0.9);
    }
    return 0.28;
  }

  /// Mock detection classification code
  String get mockDetectionCode {
    return 'RD-001';
  }

  /// Mock detection human-friendly name
  String get mockDetectionName {
    return 'Surface Anomaly';
  }

  /// Severity code derived from similarity score (mock logic)
  String get mockSeverityCode {
    if (_similarityScore >= 0.9) return 'D40';
    if (_similarityScore >= 0.75) return 'D20';
    if (_similarityScore >= 0.6) return 'D10';
    return 'D00';
  }

  /// Severity label text
  String get mockSeverityLabel {
    switch (mockSeverityCode) {
      case 'D40':
        return 'Heavy';
      case 'D20':
        return 'Moderate';
      case 'D10':
        return 'Minor';
      default:
        return 'Light';
    }
  }

  VisionController({this.inferenceService}) {
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  Future<void> initCamera() async {
    if (_isDisposed || _isInitializing) {
      return;
    }

    _isInitializing = true;
    isLoading = true;
    loadingMessage = 'Menghubungkan ke Sensor Visual...';
    errorMessage = null;
    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      final permissionStatus = await Permission.camera.request();
      if (permissionStatus.isDenied ||
          permissionStatus.isPermanentlyDenied ||
          permissionStatus.isRestricted) {
        errorMessage = 'No Camera Access';
        isInitialized = false;
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage = "No camera detected on device.";
        return;
      }

      await releaseCamera();

      controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller!.initialize();
      isInitialized = true;
      errorMessage = null;
      if (isTorchEnabled) {
        await _setTorchMode(true);
      }
    } catch (e) {
      errorMessage = "Failed to initialize camera: $e";
    } finally {
      isLoading = false;
      _isInitializing = false;
    }

    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }

  Future<void> releaseCamera() async {
    isTorchEnabled = false;
    isLoading = false;

    final currentController = controller;
    controller = null;
    isInitialized = false;

    if (currentController != null) {
      await currentController.dispose();
    }
  }

  Future<void> toggleTorch() async {
    if (!isInitialized || controller == null) {
      return;
    }

    final nextValue = !isTorchEnabled;
    await _setTorchMode(nextValue);
    isTorchEnabled = nextValue;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _setTorchMode(bool enabled) async {
    final cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    try {
      await cameraController.setFlashMode(
        enabled ? FlashMode.torch : FlashMode.off,
      );
    } catch (_) {}
  }

  void toggleOverlay() {
    isOverlayEnabled = !isOverlayEnabled;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void setFilter(VisionFilterType filter) {
    selectedFilter = filter;
    selectedPreset = VisionPresetStyle.original;
    selectedInteractiveFilter = VisionInteractiveFilterId.natural;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void applyPreset(VisionPresetStyle preset) {
    selectedPreset = preset;
    final config = visionPresetConfig(preset);
    applyContrast = config.applyContrast;
    selectedFilter = config.filterType;
    filterIntensity = config.filterIntensity;
    customContrast = 1.0;
    customBrightness = 0.0;
    customSaturation = 1.0;
    selectedInteractiveFilter = VisionInteractiveFilterId.natural;
    if (!_isDisposed) {
      notifyListeners();
    }
    requestReprocessCapturedFrame();
  }

  void selectInteractiveFilter(VisionInteractiveFilterId id) {
    final selected = visionInteractiveFilters.firstWhere(
      (item) => item.id == id,
      orElse: () => visionInteractiveFilters.first,
    );

    selectedInteractiveFilter = selected.id;
    selectedPreset = VisionPresetStyle.original;
    applyContrast = selected.applyContrast;
    selectedFilter = selected.filterType;
    filterIntensity = selected.filterIntensity;
    customContrast = selected.customContrast;
    customBrightness = selected.customBrightness;
    customSaturation = selected.customSaturation;
    showHistogram = selected.showHistogram;

    if (!_isDisposed) {
      notifyListeners();
    }

    requestReprocessCapturedFrame();
  }

  void setFilterIntensity(double value) {
    filterIntensity = value.clamp(0.0, 1.0);
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void toggleContrast(bool value) {
    applyContrast = value;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void toggleHistogram(bool value) {
    showHistogram = value;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void requestReprocessCapturedFrame() {
    if (capturedImageBytes == null || isProcessing) {
      return;
    }

    _processDebounceTimer?.cancel();
    _processDebounceTimer = Timer(const Duration(milliseconds: 180), () {
      if (!_isDisposed) {
        processCapturedFrame();
      }
    });
  }

  Future<void> captureFrame() async {
    final cameraController = controller;
    if (!isInitialized ||
        cameraController == null ||
        isCapturing ||
        isProcessing) {
      return;
    }

    isCapturing = true;
    processMessage = 'Menangkap gambar...';
    if (!_isDisposed) {
      notifyListeners();
    }

    try {
      final captured = await cameraController.takePicture();
      capturedImageBytes = await captured.readAsBytes();
      processedImageBytes = capturedImageBytes;
      histogramBins = null;
      selectedInteractiveFilter = VisionInteractiveFilterId.natural;
      applyContrast = false;
      selectedFilter = VisionFilterType.none;
      filterIntensity = 0.0;
      customContrast = 1.0;
      customBrightness = 0.0;
      customSaturation = 1.0;
      selectedPreset = VisionPresetStyle.original;
      showHistogram = true;
      
      unawaited(generateInteractiveFilterPreviews());
      requestReprocessCapturedFrame();
      processMessage = 'Gambar berhasil ditangkap. Siap diproses.';
    } catch (e) {
      processMessage = 'Gagal menangkap gambar: $e';
    } finally {
      isCapturing = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> processCapturedFrame() async {
    final sourceBytes = capturedImageBytes;
    if (isProcessing) {
      return;
    }

    if (sourceBytes == null) {
      processMessage = 'Belum ada gambar. Tekan Capture dulu.';
      _similarityScore = 0.0;
      _isSignatureValid = false;
      if (!_isDisposed) {
        notifyListeners();
      }
      return;
    }

    isProcessing = true;
    processMessage = 'Tahap 1: Mengekstraksi Area Tanda Tangan...';
    if (!_isDisposed) notifyListeners();

    try {
      // ─────────────────────────────────────────────────────────────
      // 1. TAHAP AKUISISI & ROI (Anggota 1)
      // ─────────────────────────────────────────────────────────────
      final preprocessingPipeline = PreprocessingPipeline();
      // Memasukkan gambar utuh dari kamera ke pipeline Anggota 1
      final prepResult = await preprocessingPipeline.process(sourceBytes);

      // Menangkap DTO Koordinat dari Anggota 1 dan menyimpannya ke state
      _signatureBoundingBox = Rect.fromLTWH(
        prepResult.boundingBoxX.toDouble(),
        prepResult.boundingBoxY.toDouble(),
        prepResult.boundingBoxWidth.toDouble(),
        prepResult.boundingBoxHeight.toDouble(),
      );

      processMessage = 'Tahap 2: Memproses citra digital...';
      if (!_isDisposed) notifyListeners();

      // ─────────────────────────────────────────────────────────────
      // 2. TAHAP PENGOLAHAN CITRA / TEPI (Anggota 2)
      // ─────────────────────────────────────────────────────────────
      // Di sini kita melempar gambar ke algoritma Anggota 2.
      // Catatan: Jika ingin efek filter visual diterapkan hanya pada kotak ROI,
      // ubah 'sourceBytes' di bawah menjadi 'prepResult.outputBytes'.
      final result = await VisionImageProcessor.process(
        sourceBytes: sourceBytes, 
        applyContrast: applyContrast,
        filterType: selectedFilter,
        filterIntensity: filterIntensity,
        presetStyle: selectedPreset,
        customContrast: customContrast,
        customBrightness: customBrightness,
        customSaturation: customSaturation,
        includeHistogram: showHistogram,
      );

      processedImageBytes = result.imageBytes;
      histogramBins = result.histogramBins;

      processMessage = 'Tahap 3: Memverifikasi Tanda Tangan...';
      if (!_isDisposed) notifyListeners();

      // ─────────────────────────────────────────────────────────────
      // 3. TAHAP MACHINE LEARNING (Anggota 3) - Placeholder
      // ─────────────────────────────────────────────────────────────
      // Panggil InferenceService untuk melakukan verifikasi ke server ML
      try {
        final InferenceService inference;
        if (inferenceService != null) {
          inference = inferenceService!;
        } else {
          final baseUrl = (dotenv.isInitialized ? (dotenv.env['INFER_BASE_URL'] ?? 'http://127.0.0.1:8000') : 'http://127.0.0.1:8000');
          inference = InferenceService(baseUrl: baseUrl);
        }

        // prepResult.detectedInk adalah img.Image (dart image package)
        final contourPng = img_lib.encodePng(prepResult.detectedInk);
        final featureReady = prepResult.outputBytes;

        processMessage = 'Menghubungi server verifikasi...';
        if (!_isDisposed) notifyListeners();

        final inf = await inference.infer(
          contourBytes: Uint8List.fromList(contourPng),
          featureReadyBytes: featureReady,
          enrolledLabel: null,
          threshold: 0.75,
        );

        _similarityScore = inf.similarity;
        _isSignatureValid = inf.valid;
        processMessage = 'Verifikasi selesai.';
      } catch (e) {
        // Jika server tidak tersedia atau error, tetap tidak crash: simulasikan fallback
        processMessage = 'Verifikasi gagal: $e';
        _similarityScore = 0.0;
        _isSignatureValid = false;
      }
    } catch (e) {
      processMessage = 'Gagal memproses citra: $e';
      _signatureBoundingBox = null; // Reset letak kotak jika gagal
    } finally {
      isProcessing = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> generateInteractiveFilterPreviews() async {
    final sourceBytes = capturedImageBytes;
    if (sourceBytes == null) {
      return;
    }

    final generationId = ++_previewGenerationToken;
    filterPreviewBytes = const <VisionInteractiveFilterId, Uint8List>{};
    isGeneratingFilterPreviews = true;
    if (!_isDisposed) {
      notifyListeners();
    }

    final nextPreviews = <VisionInteractiveFilterId, Uint8List>{};
    for (final item in visionInteractiveFilters) {
      try {
        final result = await VisionImageProcessor.process(
          sourceBytes: sourceBytes,
          applyContrast: item.applyContrast,
          filterType: item.filterType,
          filterIntensity: item.filterIntensity,
          presetStyle: VisionPresetStyle.original,
          customContrast: item.customContrast,
          customBrightness: item.customBrightness,
          customSaturation: item.customSaturation,
          maxDimension: 220,
          includeHistogram: false,
        );

        if (_isDisposed || generationId != _previewGenerationToken) {
          return;
        }

        nextPreviews[item.id] = result.imageBytes;
        filterPreviewBytes = Map<VisionInteractiveFilterId, Uint8List>.from(
          nextPreviews,
        );
        if (!_isDisposed) {
          notifyListeners();
        }
      } catch (_) {
        if (_isDisposed || generationId != _previewGenerationToken) {
          return;
        }
      }
    }

    if (_isDisposed || generationId != _previewGenerationToken) {
      return;
    }

    isGeneratingFilterPreviews = false;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (!isInitialized && !_isInitializing) {
        initCamera();
      } else if (isInitialized && isTorchEnabled) {
        _setTorchMode(true);
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      releaseCamera().then((_) {
        if (!_isDisposed) {
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _processDebounceTimer?.cancel();
    _processDebounceTimer = null;
    controller?.dispose();
    controller = null;
    isInitialized = false;
    super.dispose();
  }
}