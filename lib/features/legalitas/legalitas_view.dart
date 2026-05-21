import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LegalitasView extends StatefulWidget {
  const LegalitasView({super.key});

  @override
  State<LegalitasView> createState() => _LegalitasViewState();
}

class _LegalitasViewState extends State<LegalitasView> {
  final List<File> _documents = [];
  bool _isUploading = false;

  Future<void> _pickDocument() async {
    // Placeholder: in a real app, use file_picker package
    // For now, show a dialog indicating the feature
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur upload dokumen akan segera tersedia'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Legalitas')),
      body: _documents.isEmpty ? _buildEmptyState(theme) : _buildDocumentList(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickDocument,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Dokumen'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: theme.colorScheme.primary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('Belum ada dokumen', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Upload dokumen yang akan dilegalitas',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(doc.path.split('/').last),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() => _documents.removeAt(index));
              },
            ),
          ),
        );
      },
    );
  }
}
