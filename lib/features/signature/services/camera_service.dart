import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service untuk akuisisi citra - inisialisasi kamera, capture, validasi frame.
class SignatureCameraService {
  CameraController? _controller;
  bool _isInitialized = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('Tidak ada kamera tersedia');

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    _isInitialized = true;
  }

  /// Capture gambar, validasi, dan simpan ke storage.
  /// Returns path file yang tersimpan.
  Future<String> captureAndSave() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Kamera belum diinisialisasi');
    }

    final xFile = await _controller!.takePicture();
    final bytes = await xFile.readAsBytes();

    // Validasi frame: minimal 10KB untuk memastikan bukan frame kosong
    if (bytes.length < 10240) {
      throw Exception('Frame tidak valid - ukuran terlalu kecil');
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/signature_capture_$timestamp.jpg';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Capture dan return bytes langsung tanpa menyimpan ke disk.
  Future<Uint8List> captureBytes() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Kamera belum diinisialisasi');
    }

    final xFile = await _controller!.takePicture();
    final bytes = await xFile.readAsBytes();

    if (bytes.length < 10240) {
      throw Exception('Frame tidak valid');
    }
    return bytes;
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
