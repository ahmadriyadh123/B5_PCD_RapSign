import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/verification_log_model.dart';
import 'services/verification_mongo_service.dart';
import 'signature_verification_controller.dart';

// ─── Design Tokens (konsisten dengan main.dart) ───────────────
class _T {
  static const warmBrown    = Color(0xFF8A6F4D);
  static const mutedGold    = Color(0xFFC2A35C);
  static const warmBeige    = Color(0xFFE6D8C3);
  static const softCream    = Color(0xFFF3EBDD);
  static const charcoal     = Color(0xFF3D3D3D);
  static const taupe        = Color(0xFF8B7D6B);
  static const validGreen   = Color(0xFF2E7D32);
  static const validBg      = Color(0xFFE8F5E9);
  static const invalidRed   = Color(0xFF9E5A5A);
  static const invalidBg    = Color(0xFFF5E0DC);
}

class SignatureVerificationView extends StatefulWidget {
  final String username;

  const SignatureVerificationView({super.key, required this.username});

  @override
  State<SignatureVerificationView> createState() =>
      _SignatureVerificationViewState();
}

class _SignatureVerificationViewState extends State<SignatureVerificationView> {
  late SignatureVerificationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureVerificationController(username: widget.username);
    _controller.addListener(_onUpdate);
    _controller.init();
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Tanda Tangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Riwayat Verifikasi',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VerificationHistoryView(username: widget.username),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_controller.state) {
      case SignatureVerificationState.result:
        return _buildResultView();
      default:
        return _buildMainView();
    }
  }

  // ─── Main View ───────────────────────────────────────────────
  Widget _buildMainView() {
    return Column(
      children: [
        _buildServerBanner(),
        Expanded(child: _buildCameraSection()),
        _buildControlPanel(),
      ],
    );
  }

  Widget _buildServerBanner() {
    if (_controller.isLoadingLabels) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: _T.mutedGold.withValues(alpha: 0.15),
        child: const Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Menghubungi server...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (!_controller.isServerOnline) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: _T.invalidRed.withValues(alpha: 0.10),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 16, color: _T.invalidRed),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Server tidak terhubung. Pastikan FastAPI server berjalan.',
                style: TextStyle(fontSize: 12, color: _T.invalidRed),
              ),
            ),
            TextButton(
              onPressed: _controller.retryServerCheck,
              child: const Text('Coba Lagi', style: TextStyle(fontSize: 12, color: _T.warmBrown)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: _T.validGreen.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_rounded, size: 14, color: _T.validGreen),
          const SizedBox(width: 8),
          Text(
            'Server aktif · ${_controller.availableLabels.length} identitas terdaftar',
            style: const TextStyle(fontSize: 12, color: _T.validGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    if (!_controller.isCameraInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _T.mutedGold),
              const SizedBox(height: 16),
              Text(
                _controller.errorMessage ?? 'Memuat kamera...',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.state == SignatureVerificationState.processing) {
      return Stack(
        children: [
          _buildCameraPreview(),
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _T.mutedGold),
                  SizedBox(height: 16),
                  Text('Menganalisis tanda tangan...',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                  SizedBox(height: 8),
                  Text('Mengirim ke server · Memproses kontur · Verifikasi CNN',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_controller.state == SignatureVerificationState.error) {
      return Container(
        color: const Color(0xFF1A0E04),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: _T.invalidRed, size: 48),
                const SizedBox(height: 16),
                Text(
                  _controller.errorMessage ?? 'Terjadi kesalahan.',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _controller.reset, child: const Text('Coba Lagi')),
              ],
            ),
          ),
        ),
      );
    }

    return _buildCameraPreview();
  }

  Widget _buildCameraPreview() {
    final cam = _controller.cameraController!;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenRatio = constraints.maxWidth / constraints.maxHeight;
              final cameraRatio = cam.value.aspectRatio;
              final fit = cameraRatio > screenRatio ? BoxFit.fitHeight : BoxFit.fitWidth;
              return FittedBox(
                fit: fit,
                child: SizedBox(
                  width: cam.value.previewSize?.height ?? 100,
                  height: cam.value.previewSize?.width ?? 100,
                  child: CameraPreview(cam),
                ),
              );
            },
          ),
        ),
        const _SignatureGuideOverlay(),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: _T.softCream,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_controller.availableLabels.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: _T.taupe),
                const SizedBox(width: 8),
                const Text('Verifikasi sebagai:',
                    style: TextStyle(fontSize: 13, color: _T.taupe, fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _controller.selectedLabel,
                    isExpanded: true,
                    underline: const Divider(height: 1, color: _T.taupe, thickness: 0.5),
                    items: _controller.availableLabels
                        .map((label) => DropdownMenuItem(
                              value: label,
                              child: Text(label,
                                  style: const TextStyle(fontSize: 14, color: _T.charcoal)),
                            ))
                        .toList(),
                    onChanged: _controller.setSelectedLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _controller.isProcessing || !_controller.isServerOnline
                      ? null
                      : _controller.pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Galeri'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _T.warmBrown,
                    side: const BorderSide(color: _T.warmBrown),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _controller.isProcessing ||
                          !_controller.isCameraInitialized ||
                          !_controller.isServerOnline
                      ? null
                      : _controller.captureAndVerify,
                  icon: _controller.isProcessing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 20),
                  label: Text(
                    _controller.isProcessing ? 'Memproses...' : 'Ambil & Verifikasi',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.warmBrown,
                    foregroundColor: _T.softCream,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Result View ─────────────────────────────────────────────
  Widget _buildResultView() {
    final result = _controller.lastResult!;
    final isValid = result.isValid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isValid ? _T.validBg : _T.invalidBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isValid
                    ? _T.validGreen.withValues(alpha: 0.4)
                    : _T.invalidRed.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isValid ? Icons.verified_rounded : Icons.cancel_rounded,
                  size: 56,
                  color: isValid ? _T.validGreen : _T.invalidRed,
                ),
                const SizedBox(height: 12),
                Text(
                  isValid ? 'TANDA TANGAN VALID' : 'TANDA TANGAN TIDAK VALID',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: isValid ? _T.validGreen : _T.invalidRed,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isValid
                      ? 'Tanda tangan terverifikasi milik ${result.enrolledLabel}'
                      : 'Tanda tangan tidak cocok dengan ${result.enrolledLabel}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isValid
                        ? _T.validGreen.withValues(alpha: 0.8)
                        : _T.invalidRed.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _T.softCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _T.taupe.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detail Verifikasi',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _T.charcoal)),
                const SizedBox(height: 12),
                _detailRow('Identitas Diklaim', result.enrolledLabel),
                _detailRow('Prediksi CNN', result.predictedLabel),
                _detailRow(
                  'Skor Kemiripan',
                  '${((result.similarityScore < 0 ? 0.0 : result.similarityScore) * 100).toStringAsFixed(1)}%',
                  valueColor: isValid ? _T.validGreen : _T.invalidRed,
                ),
                _detailRow('Threshold', '${(result.thresholdUsed * 100).toStringAsFixed(0)}%'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: result.similarityScore.clamp(0.0, 1.0),
                    backgroundColor: _T.warmBeige,
                    color: isValid ? _T.validGreen : _T.invalidRed,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (result.contourImageBytes != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _T.softCream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _T.taupe.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hasil Ekstraksi Kontur',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _T.charcoal)),
                  const SizedBox(height: 4),
                  const Text(
                    'Grayscale → noise reduction → thresholding → edge detection → morphological operation',
                    style: TextStyle(fontSize: 11, color: _T.taupe),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(result.contourImageBytes!, fit: BoxFit.contain, width: double.infinity),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VerificationHistoryView(username: widget.username),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Riwayat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _T.warmBrown,
                    side: const BorderSide(color: _T.warmBrown),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _controller.reset,
                  icon: const Icon(Icons.add_a_photo_rounded, size: 20),
                  label: const Text('Verifikasi Baru',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.warmBrown,
                    foregroundColor: _T.softCream,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 2,
              child: Text(label, style: const TextStyle(fontSize: 13, color: _T.taupe))),
          Expanded(flex: 3,
              child: Text(value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: valueColor ?? _T.charcoal))),
        ],
      ),
    );
  }
}

// ─── Guide Overlay ────────────────────────────────────────────
class _SignatureGuideOverlay extends StatelessWidget {
  const _SignatureGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GuideFramePainter(),
        child: Align(
          alignment: const Alignment(0, 0.6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Arahkan ke area tanda tangan',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameW = size.width * 0.75;
    final frameH = size.height * 0.28;
    final frameLeft = (size.width - frameW) / 2;
    final frameTop = (size.height - frameH) / 2 - 20;

    final paint = Paint()
      ..color = const Color(0xFFC2A35C).withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const cornerLen = 24.0;
    final tl = Offset(frameLeft, frameTop);
    final tr = Offset(frameLeft + frameW, frameTop);
    final bl = Offset(frameLeft, frameTop + frameH);
    final br = Offset(frameLeft + frameW, frameTop + frameH);

    canvas
      ..drawLine(tl, tl + const Offset(cornerLen, 0), paint)
      ..drawLine(tl, tl + const Offset(0, cornerLen), paint)
      ..drawLine(tr, tr + const Offset(-cornerLen, 0), paint)
      ..drawLine(tr, tr + const Offset(0, cornerLen), paint)
      ..drawLine(bl, bl + const Offset(cornerLen, 0), paint)
      ..drawLine(bl, bl + const Offset(0, -cornerLen), paint)
      ..drawLine(br, br + const Offset(-cornerLen, 0), paint)
      ..drawLine(br, br + const Offset(0, -cornerLen), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── History View ─────────────────────────────────────────────
class VerificationHistoryView extends StatefulWidget {
  final String username;
  const VerificationHistoryView({super.key, required this.username});

  @override
  State<VerificationHistoryView> createState() => _VerificationHistoryViewState();
}

class _VerificationHistoryViewState extends State<VerificationHistoryView> {
  List<VerificationLogModel> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await VerificationMongoService().getLogs(verifiedBy: widget.username);
      setState(() => _logs = logs);
    } catch (_) {
      final box = await Hive.openBox<VerificationLogModel>('verification_logs');
      setState(() => _logs = box.values.toList().reversed.toList());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Verifikasi')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Text('Belum ada riwayat verifikasi.',
                      style: TextStyle(color: _T.taupe)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isValid = log.status == VerificationStatus.valid;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isValid ? _T.validBg : _T.invalidBg,
                          child: Icon(
                            isValid ? Icons.verified_rounded : Icons.cancel_rounded,
                            color: isValid ? _T.validGreen : _T.invalidRed,
                            size: 22,
                          ),
                        ),
                        title: Text(log.enrolledLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Skor: ${((log.similarityScore < 0 ? 0.0 : log.similarityScore) * 100).toStringAsFixed(1)}% · ${log.timestamp.substring(0, 16).replaceAll('T', ' ')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isValid ? _T.validBg : _T.invalidBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isValid ? 'VALID' : 'INVALID',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: isValid ? _T.validGreen : _T.invalidRed,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}