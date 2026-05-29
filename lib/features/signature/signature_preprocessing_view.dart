import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import 'services/camera_service.dart';
import 'services/preprocessing_pipeline.dart';

/// View untuk modul preprocessing tanda tangan via kamera.
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

  void _reset() => setState(() { _result = null; _error = null; });

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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _result == null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_result != null) return _buildResultView();
    return _buildCameraView();
  }

  Widget _buildCameraView() {
    if (!_cameraService.isInitialized || _cameraService.controller == null) {
      return const Center(child: Text('Kamera tidak tersedia'));
    }
    return Column(
      children: [
        Expanded(child: CameraPreview(_cameraService.controller!)),
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
              _card('1. Original', img.encodePng(r.originalImage)),
              _card('2. Crop Dokumen', img.encodePng(r.croppedDocument)),
              _card('3. Deteksi Coretan Bawah', img.encodePng(r.detectedInk)),
              _card('4. Segmentasi', img.encodePng(r.segmentedImage)),
              _card('5. Normalized', r.outputBytes),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh), label: const Text('Ulang')),
        ),
      ],
    );
  }

  Widget _card(String title, List<int> bytes) {
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
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            child: Image.memory(Uint8List.fromList(bytes), width: double.infinity, fit: BoxFit.contain, height: 180),
          ),
        ],
      ),
    );
  }
}
