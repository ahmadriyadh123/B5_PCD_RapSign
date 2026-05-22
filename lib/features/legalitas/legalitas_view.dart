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
  PreprocessingResult? _result;
  String? _error;

  Future<void> _pickDocument() async {
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

    setState(() { _isProcessing = true; _result = null; _error = null; });

    try {
      final bytes = await File(xFile.path).readAsBytes();
      final result = await _pipeline.process(bytes);
      setState(() { _result = result; _isProcessing = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isProcessing = false; });
    }
  }

  void _reset() => setState(() { _result = null; _error = null; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legalitas')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isProcessing) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Memproses...')],
      ));
    }
    if (_error != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _reset, child: const Text('Coba Lagi')),
        ],
      ));
    }
    if (_result != null) return _buildResultView();
    return Center(
      child: ElevatedButton.icon(
        onPressed: _pickDocument,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Dokumen'),
      ),
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
              _card('1. Dokumen Asli (${r.originalImage.width}×${r.originalImage.height})',
                  img.encodePng(r.originalImage)),
              _card('2. Crop Dokumen Putih (${r.croppedDocument.width}×${r.croppedDocument.height})',
                  img.encodePng(r.croppedDocument)),
              _card('3. Deteksi Coretan Bawah (${r.detectedInk.width}×${r.detectedInk.height})',
                  img.encodePng(r.detectedInk)),
              _card('4. Segmentasi (${r.segmentedImage.width}×${r.segmentedImage.height})',
                  img.encodePng(r.segmentedImage)),
              _card('5. Normalized (${r.normalizedImage.width}×${r.normalizedImage.height})',
                  r.outputBytes),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _pickDocument,
                icon: const Icon(Icons.refresh),
                label: const Text('Upload Baru'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tanda tangan berhasil diekstrak')),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Simpan'),
              )),
            ],
          ),
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
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Image.memory(
              Uint8List.fromList(bytes),
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
