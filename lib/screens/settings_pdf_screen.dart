import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';

class SettingsPdfScreen extends StatefulWidget {
  const SettingsPdfScreen({super.key});

  @override
  State<SettingsPdfScreen> createState() => _SettingsPdfScreenState();
}

class _SettingsPdfScreenState extends State<SettingsPdfScreen> {
  final _db = DatabaseHelper.instance;
  final _clinicNameController = TextEditingController();
  final _commentsController = TextEditingController();

  static const _pdfClinicNameKey = 'pdf.clinic_name';
  static const _pdfLogoAssetKey = 'pdf.logo_asset';
  static const _pdfLogoCustomBase64Key = 'pdf.logo_custom_base64';
  static const _pdfCommentsKey = 'pdf.additional_comments';
  static const _defaultClinicName = 'Clínica Dental Huberto Merino';

  Uint8List? _customLogoBytes;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clinicNameController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final clinicName = await _db.getAppSetting(_pdfClinicNameKey);
    final comments = await _db.getAppSetting(_pdfCommentsKey);
    final customLogoBase64 = await _db.getAppSetting(_pdfLogoCustomBase64Key);

    Uint8List? logoBytes;
    if (customLogoBase64 != null && customLogoBase64.trim().isNotEmpty) {
      try {
        logoBytes = base64Decode(customLogoBase64.trim());
      } catch (_) {
        logoBytes = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _clinicNameController.text = (clinicName == null || clinicName.trim().isEmpty)
          ? _defaultClinicName
          : clinicName.trim();
      _commentsController.text = comments ?? '';
      _customLogoBytes = logoBytes;
      _loading = false;
    });
  }

  Future<void> _pickCustomLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    final bytes = result?.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;

    if (!mounted) return;
    setState(() => _customLogoBytes = bytes);
  }

  Future<void> _removeCustomLogo() async {
    if (!mounted) return;
    setState(() => _customLogoBytes = null);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final clinicName = _clinicNameController.text.trim();
    final comments = _commentsController.text.trim();

    await _db.setAppSetting(_pdfClinicNameKey, clinicName.isEmpty ? _defaultClinicName : clinicName);
    await _db.setAppSetting(_pdfCommentsKey, comments);
    await _db.setAppSetting(_pdfLogoAssetKey, 'assets/images/LOGOSINFONDO.png');
    await _db.setAppSetting(
      _pdfLogoCustomBase64Key,
      _customLogoBytes == null ? null : base64Encode(_customLogoBytes!),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajustes de PDF guardados.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('PDF')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _clinicNameController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la clínica',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentsController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Comentarios adicionales',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logo para el PDF',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_customLogoBytes == null)
                    const Text('No hay logo personalizado cargado.')
                  else
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Image.memory(_customLogoBytes!, fit: BoxFit.contain),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickCustomLogo,
                        icon: const Icon(Icons.upload_file),
                        label: Text(_customLogoBytes == null ? 'Subir logo' : 'Cambiar logo'),
                      ),
                      if (_customLogoBytes != null)
                        OutlinedButton.icon(
                          onPressed: _removeCustomLogo,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Quitar logo'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
