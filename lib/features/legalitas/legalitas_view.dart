import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../signature/services/preprocessing_pipeline.dart';

class LegalitasView extends StatefulWidget {
  const LegalitasView({super.key});

  @override
  State<LegalitasView> createState() => _LegalitasViewState();
}

class _LegalitasViewState extends State<LegalitasView> {
  final ImagePicker _picker = ImagePicker();
  final PreprocessingPipeline _pipeline = PreprocessingPipeline();

  bool _isProcessing = false;
  File? _documentFile;
  PreprocessingResult? _result;
  String? _error;

  Future<void> _pickDocument() async {
    // Pilih sumber: galeri atau kamera
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final xFile = await _picker.pickImage(source: source, imageQuality: 90);
    if (xFile == null) return;

    setState(() {
      _documentFile = File(xFile.path);
      _isProcessing = true;
      _result = null;
      _error = null;
    });

    try {
      final bytes = await _documentFile!.readAsBytes();
      final result = await _pipeline.process(bytes);
      setState(() { _result = result; _isProcessing = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isProcessing = false; });
    }
  }

  void _reset() {
    setState(() {
      _documentFile = null;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Legalitas')),
      body: _buildBody(theme),
      floatingActionButton: _result == null
          ? FloatingActionButton.extended(
              onPressed: _isProcessing ? null : _pickDocument,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Dokumen'),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Mendeteksi tanda tangan...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _reset, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_result != null) {
      return _buildResultView(theme);
    }

    return _buildEmptyState(theme);
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Belum ada dokumen', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Upload dokumen untuk mendeteksi tanda tangan', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildResultView(ThemeData theme) {
    final r = _result!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildStepCard('Dokumen Asli', img.encodePng(r.originalImage), theme),
              _buildStepCard('ROI (Area Tanda Tangan)', img.encodePng(r.roiImage), theme),
              _buildStepCard('Segmentasi', img.encodePng(r.segmentedImage), theme),
              _buildStepCard(
                'Hasil Deteksi (${r.normalizedImage.width}×${r.normalizedImage.height})',
                r.outputBytes,
                theme,
              ),
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
                  label: const Text('Upload Baru'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tanda tangan berhasil diekstrak')),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard(String title, List<int> imageBytes, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(title, style: theme.textTheme.titleSmall),
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
              height: 200,
            ),
          ),
        ],
      ),
    );
  }
}
