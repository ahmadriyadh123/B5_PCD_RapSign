import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service untuk akuisisi citra - inisialisasi kamera, frame stream, capture.
class SignatureCameraService {
  CameraController? _controller;
  bool _isInitialized = false;
  StreamController<CameraImage>? _frameStreamController;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  /// Stream frame mentah dari kamera untuk live processing.
  Stream<CameraImage>? get frameStream => _frameStreamController?.stream;

  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> initialize({ResolutionPreset resolution = ResolutionPreset.high}) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('Tidak ada kamera tersedia');

    _controller = CameraController(
      cameras[0],
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    _isInitialized = true;
  }

  /// Mulai streaming frame untuk live processing (quality check, preview overlay).
  Future<void> startFrameStream() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Kamera belum diinisialisasi');
    }
    _frameStreamController = StreamController<CameraImage>.broadcast();
    await _controller!.startImageStream((CameraImage image) {
      if (_frameStreamController != null && !_frameStreamController!.isClosed) {
        _frameStreamController!.add(image);
      }
    });
  }

  /// Hentikan streaming frame.
  Future<void> stopFrameStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    await _frameStreamController?.close();
    _frameStreamController = null;
  }

  /// Capture gambar, validasi, dan simpan ke storage.
  Future<String> captureAndSave() async {
    _ensureReady();
    // Stop stream sementara jika aktif (wajib sebelum takePicture)
    final wasStreaming = _controller!.value.isStreamingImages;
    if (wasStreaming) await stopFrameStream();

    final xFile = await _controller!.takePicture();
    final bytes = await xFile.readAsBytes();
    _validateFrame(bytes);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/signature_capture_$timestamp.jpg';
    await File(path).writeAsBytes(bytes);

    // Resume stream jika sebelumnya aktif
    if (wasStreaming) await startFrameStream();
    return path;
  }

  /// Capture dan return bytes langsung tanpa menyimpan ke disk.
  Future<Uint8List> captureBytes() async {
    _ensureReady();
    final wasStreaming = _controller!.value.isStreamingImages;
    if (wasStreaming) await stopFrameStream();

    final xFile = await _controller!.takePicture();
    final bytes = await xFile.readAsBytes();
    _validateFrame(bytes);

    if (wasStreaming) await startFrameStream();
    return bytes;
  }

  /// Konversi CameraImage (YUV420) ke luminance bytes untuk analisis cepat.
  static Uint8List extractLuminance(CameraImage image) {
    // Plane 0 pada YUV420 adalah Y (luminance)
    return image.planes[0].bytes;
  }

  void _ensureReady() {
    if (!_isInitialized || _controller == null) {
      throw Exception('Kamera belum diinisialisasi');
    }
  }

  void _validateFrame(Uint8List bytes) {
    if (bytes.length < 10240) {
      throw Exception('Frame tidak valid - ukuran terlalu kecil');
    }
  }

  void dispose() {
    stopFrameStream();
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
