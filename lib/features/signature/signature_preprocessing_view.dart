import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import 'services/camera_service.dart';
import 'services/preprocessing_pipeline.dart';

/// View untuk modul preprocessing tanda tangan.
/// Menampilkan camera preview, capture, dan hasil preprocessing step-by-step.
class SignaturePreprocessingView extends StatefulWidget {
  const SignaturePreprocessingView({super.key});

  @override
  State<SignaturePreprocessingView> createState() => _SignaturePreprocessingViewState();
}

class _SignaturePreprocessingViewState extends State<SignaturePreprocessingView> {
  final SignatureCameraService _cameraService = SignatureCameraService();
  final PreprocessingPipeline _pipeline = PreprocessingPipeline();

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  PreprocessingResult? _result;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final granted = await _cameraService.requestPermission();
      if (!granted) {
        setState(() { _error = 'Izin kamera ditolak'; _isLoading = false; });
        return;
      }
      await _cameraService.initialize();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _capture() async {
    setState(() { _isProcessing = true; _error = null; });
    try {
      final bytes = await _cameraService.captureBytes();
      final result = await _pipeline.process(bytes);
      setState(() { _result = result; _isProcessing = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isProcessing = false; });
    }
  }

  void _reset() {
    setState(() => _result = null);
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preprocessing Tanda Tangan')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _result == null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_result != null) {
      return _buildResultView();
    }
    return _buildCameraView();
  }

  Widget _buildCameraView() {
    if (!_cameraService.isInitialized || _cameraService.controller == null) {
      return const Center(child: Text('Kamera tidak tersedia'));
    }
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CameraPreview(_cameraService.controller!),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _capture,
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.camera_alt),
              label: Text(_isProcessing ? 'Memproses...' : 'Capture & Proses'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final r = _result!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildStepCard('1. Original', img.encodePng(r.originalImage)),
              _buildStepCard('2. ROI Extraction', img.encodePng(r.roiImage)),
              _buildStepCard('3. Segmentation', img.encodePng(r.segmentedImage)),
              _buildStepCard('4. Normalized (${r.normalizedImage.width}x${r.normalizedImage.height})', r.outputBytes),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Ulang'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hasil siap untuk preprocessing lanjutan')),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Gunakan'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard(String title, List<int> imageBytes) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Image.memory(
              Uint8List.fromList(imageBytes),
              width: double.infinity,
              fit: BoxFit.contain,
              height: 180,
            ),
          ),
        ],
      ),
    );
  }
}
