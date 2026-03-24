import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/estimate.dart';
import '../services/pdf_service.dart';
import 'create_estimate_screen.dart';

class EstimateDetailScreen extends StatefulWidget {
  final int estimateId;

  const EstimateDetailScreen({super.key, required this.estimateId});

  @override
  State<EstimateDetailScreen> createState() => _EstimateDetailScreenState();
}

class _EstimateDetailScreenState extends State<EstimateDetailScreen> {
  final _db = DatabaseHelper.instance;
  final _pdfService = PdfService.instance;
  static const _pdfClinicNameKey = 'pdf.clinic_name';
  static const _pdfLogoAssetKey = 'pdf.logo_asset';
  static const _pdfLogoCustomBase64Key = 'pdf.logo_custom_base64';
  static const _pdfCommentsKey = 'pdf.additional_comments';
  static const _defaultClinicName = 'Clínica Dental Huberto Merino';
  static const _clinicLogoAssetCandidates = [
    'assets/images/clinic_logo.png',
    'assets/images/LOGOSINFONDO.png',
    'assets/images/LOGO PERFIL WHATSAPP 3.png',
    'assets/images/app_icon.png',
  ];

  EstimateSummary? _summary;
  List<EstimateDetailView> _details = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatToothLabel(String? value) {
    final normalized = value?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return '-';
    if (normalized == 'X') return 'General (X)';
    if (normalized == '+') return 'Arcada superior (+)';
    if (normalized == '-') return 'Arcada inferior (-)';
    if (RegExp(r'^\d{2}-\d{2}$').hasMatch(normalized)) {
      return 'Sector $normalized';
    }
    return 'Pieza $normalized';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await _db.getEstimateSummary(widget.estimateId);
    final details = await _db.getEstimateDetails(widget.estimateId);

    setState(() {
      _summary = summary;
      _details = details;
      _loading = false;
    });
  }

  Future<void> _exportPdf() async {
    final summary = _summary;
    if (summary == null) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Generando PDF...')));

    final clinicNameRaw = await _db.getAppSetting(_pdfClinicNameKey);
    final logoAssetRaw = await _db.getAppSetting(_pdfLogoAssetKey);
    final logoCustomBase64 = await _db.getAppSetting(_pdfLogoCustomBase64Key);
    final additionalCommentsRaw = await _db.getAppSetting(_pdfCommentsKey);

    final clinicName = (clinicNameRaw == null || clinicNameRaw.trim().isEmpty)
        ? _defaultClinicName
        : clinicNameRaw.trim();
    final additionalComments = additionalCommentsRaw?.trim();
    final logoBytes = await _loadClinicLogoBytes(
      preferredAsset: logoAssetRaw,
      preferredBase64: logoCustomBase64,
    );

    final File file = await _pdfService.buildEstimatePdf(
      patientName: summary.patientName,
      date: summary.date,
      details: _details,
      clinicName: clinicName,
      clinicLogoBytes: logoBytes,
      additionalComments: additionalComments,
    );

    if (!mounted) return;
    messenger.hideCurrentSnackBar();

    if (logoBytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Logo no encontrado. Exportando PDF sin logo.')),
      );
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Compartir (WhatsApp, email, etc.)'),
              onTap: () async {
                Navigator.pop(context);
                await _pdfService.sharePdf(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('PDF generado en almacenamiento temporal'),
              subtitle: Text(file.path),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _loadClinicLogoBytes({
    String? preferredAsset,
    String? preferredBase64,
  }) async {
    if (preferredBase64 != null && preferredBase64.trim().isNotEmpty) {
      try {
        return base64Decode(preferredBase64.trim());
      } catch (_) {}
    }

    final orderedAssets = <String>[];
    if (preferredAsset != null && preferredAsset.trim().isNotEmpty) {
      orderedAssets.add(preferredAsset.trim());
    }
    for (final fallback in _clinicLogoAssetCandidates) {
      if (!orderedAssets.contains(fallback)) {
        orderedAssets.add(fallback);
      }
    }

    for (final assetPath in orderedAssets) {
      try {
        final data = await rootBundle.load(assetPath);
        return data.buffer.asUint8List();
      } catch (_) {}
    }
    return null;
  }

  Future<void> _deleteEstimate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar presupuesto'),
        content: const Text('¿Seguro que deseas eliminar este presupuesto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;

    await _db.deleteEstimate(widget.estimateId);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de presupuesto'),
        actions: [
          IconButton(
            onPressed: _summary == null
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateEstimateScreen(editingEstimateId: widget.estimateId),
                      ),
                    );
                    await _load();
                  },
            icon: const Icon(Icons.edit),
            tooltip: 'Editar',
          ),
          IconButton(
            onPressed: _summary == null ? null : _deleteEstimate,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
              ? const Center(child: Text('Presupuesto no encontrado'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_summary!.patientName, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 6),
                            Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(_summary!.date)}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Tratamiento')),
                            DataColumn(label: Text('Pieza')),
                            DataColumn(label: Text('Cant.')),
                            DataColumn(label: Text('P/U')),
                            DataColumn(label: Text('Total')),
                          ],
                          rows: _details
                              .map(
                                (d) => DataRow(
                                  cells: [
                                    DataCell(Text(d.treatmentName)),
                                    DataCell(Text(_formatToothLabel(d.toothCode))),
                                    DataCell(Text(d.quantity.toString())),
                                    DataCell(Text(money.format(d.unitPrice))),
                                    DataCell(Text(money.format(d.lineTotal))),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _details
                          .where((d) => d.toothCode != null)
                          .map(
                            (d) => Chip(
                              label: Text('${_formatToothLabel(d.toothCode)}: ${d.treatmentName} x${d.quantity}'),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total final: ${money.format(_summary!.total)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Exportar PDF'),
                    ),
                  ],
                ),
    );
  }
}
