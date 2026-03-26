import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/editable_estimate_line.dart';
import '../models/estimate.dart';
import '../models/patient.dart';
import '../models/treatment.dart';
import '../services/pdf_service.dart';
import '../services/speech_service.dart';
import '../services/text_parser_service.dart';
import '../widgets/odontogram_widget.dart';

class CreateEstimateScreen extends StatefulWidget {
  final int? editingEstimateId;
  final int? initialPatientId;
  final int? activeDoctorId;

  const CreateEstimateScreen({
    super.key,
    this.editingEstimateId,
    this.initialPatientId,
    this.activeDoctorId,
  });

  @override
  State<CreateEstimateScreen> createState() => _CreateEstimateScreenState();
}

class _CreateEstimateScreenState extends State<CreateEstimateScreen> {
  final _db = DatabaseHelper.instance;
  final _pdfService = PdfService.instance;
  final _speech = SpeechService.instance;
  final _parser = TextParserService.instance;
  static const _pdfClinicNameKey = 'pdf.clinic_name';
  static const _pdfLogoAssetKey = 'pdf.logo_asset';
  static const _pdfLogoCustomBase64Key = 'pdf.logo_custom_base64';
  static const _pdfCommentsKey = 'pdf.additional_comments';
  static const _defaultClinicName = 'Clínica Dental Huberto Merino';
  static const _clinicLogoAssetCandidates = [
    'assets/images/LOGO PERFIL WHATSAPP 3.png',
    'assets/images/LOGOSINFONDO.png',
    'assets/images/app_icon.png',
  ];

  final _newPatientController = TextEditingController();
  final _manualQtyController = TextEditingController(text: '1');
  final _transcriptionController = TextEditingController();

  List<Patient> _patients = [];
  List<Treatment> _treatments = [];
  List<EditableEstimateLine> _lines = [];
  Map<int, int> _treatmentUsageByDoctor = const {};

  int? _selectedPatientId;
  Treatment? _selectedManualTreatment;

  bool _isListening = false;
  bool _showTranscriptionPanel = false;
  bool _showManualTreatmentPanel = false;
  bool _saving = false;
  String _dictationCommittedText = '';
  String _dictationCurrentChunk = '';
  String _lastProcessedTranscription = '';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _removeTreatmentFromOdontogram(Treatment treatment, String toothCode) {
    final index = _lines.indexWhere(
      (line) => line.treatment.id == treatment.id && line.toothCode == toothCode,
    );
    if (index == -1) return;

    setState(() {
      if (_lines[index].quantity > 1) {
        _lines[index].quantity -= 1;
      } else {
        _lines.removeAt(index);
      }
    });
  }

  @override
  void dispose() {
    _newPatientController.dispose();
    _manualQtyController.dispose();
    _transcriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _db.ensureDefaults();

    final patients = await _db.getPatients();
    final treatments = await _db.getTreatments(doctorId: widget.activeDoctorId);
    final usageByDoctor = await _db.getTreatmentUsageCounts(doctorId: widget.activeDoctorId);

    setState(() {
      _patients = patients;
      _treatments = treatments;
      _treatmentUsageByDoctor = usageByDoctor;
      _selectedPatientId = widget.initialPatientId ?? _selectedPatientId;
      _selectedManualTreatment ??= treatments.isNotEmpty ? treatments.first : null;
    });

    if (widget.editingEstimateId != null) {
      await _loadEstimateForEdit(widget.editingEstimateId!);
    }
  }

  Future<void> _exportPdfForEstimate(int estimateId) async {
    final summary = await _db.getEstimateSummary(estimateId);
    if (summary == null) return;

    final details = await _db.getEstimateDetails(estimateId);
    final clinicNameRaw = await _db.getAppSetting(_pdfClinicNameKey);
    final logoAssetRaw = await _db.getAppSetting(_pdfLogoAssetKey);
    final logoCustomBase64 = await _db.getAppSetting(_pdfLogoCustomBase64Key);
    final additionalCommentsRaw = await _db.getAppSetting(_pdfCommentsKey);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Generando PDF...')));

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
      details: details,
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

    await showModalBottomSheet<void>(
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

  String? _normalizePieceCodeForTreatment(Treatment treatment, String? rawCode) {
    final pieceType = (treatment.pieceType ?? 'pieza').trim().toLowerCase();
    final code = _normalizePieceCode(rawCode);

    return switch (pieceType) {
      'general' => 'X',
      'arcada' => _normalizeArcadaCode(code),
      'sector' => _normalizeSectorCode(code),
      _ => _normalizePiezaCode(code),
    };
  }

  String? _normalizePiezaCode(String? code) {
    if (code == null) return null;
    if (RegExp(r'^\d{2}$').hasMatch(code)) return code;
    return null;
  }

  String? _normalizeSectorCode(String? code) {
    if (code == null) return null;
    if (RegExp(r'^\d{2}-\d{2}$').hasMatch(code)) {
      final parts = code.split('-');
      final start = parts[0];
      final end = parts[1];
      if (start[0] != end[0]) return null;
      return int.parse(start) <= int.parse(end) ? '$start-$end' : '$end-$start';
    }
    if (RegExp(r'^\d{2}$').hasMatch(code)) return code;
    return null;
  }

  String? _normalizeArcadaCode(String? code) {
    if (code == null) return null;
    if (code == '+' || code == '-') return code;
    if (RegExp(r'^\d{2}$').hasMatch(code)) {
      return (code.startsWith('1') || code.startsWith('2')) ? '+' : '-';
    }
    if (RegExp(r'^\d{2}-\d{2}$').hasMatch(code)) {
      final parts = code.split('-');
      final start = parts[0];
      final end = parts[1];
      final isUpper = (start.startsWith('1') || start.startsWith('2')) && (end.startsWith('1') || end.startsWith('2'));
      final isLower = (start.startsWith('3') || start.startsWith('4')) && (end.startsWith('3') || end.startsWith('4'));
      if (isUpper) return '+';
      if (isLower) return '-';
    }
    return null;
  }

  String? _buildNoteForTreatmentCode(Treatment treatment, String? code) {
    if (code == null) return null;
    final pieceType = (treatment.pieceType ?? 'pieza').trim().toLowerCase();
    return switch (pieceType) {
      'general' => 'General',
      'arcada' => code == '+' ? 'Arcada superior' : 'Arcada inferior',
      'sector' => code.contains('-') ? 'Sector $code' : 'Pieza $code',
      _ => 'Pieza $code',
    };
  }

  Future<void> _loadEstimateForEdit(int estimateId) async {
    final summary = await _db.getEstimateSummary(estimateId);
    final details = await _db.getEstimateDetails(estimateId);
    if (summary == null) return;

    final treatmentMap = {for (final t in _treatments) t.id!: t};

    setState(() {
      _selectedPatientId = summary.patientId;
      _selectedDate = summary.date;
      _lines = details
          .where((d) => treatmentMap.containsKey(d.treatmentId))
          .map(
            (d) => EditableEstimateLine(
              treatment: treatmentMap[d.treatmentId]!,
              quantity: d.quantity,
              unitPrice: d.unitPrice,
              toothCode: d.toothCode,
            ),
          )
          .toList();
    });
  }

  Future<void> _createPatient() async {
    final name = _newPatientController.text.trim();
    if (name.isEmpty) return;

    final id = await _db.insertPatient(
      Patient(name: name),
      doctorId: widget.activeDoctorId,
    );
    _newPatientController.clear();

    final patients = await _db.getPatients();
    setState(() {
      _patients = patients;
      _selectedPatientId = id;
    });
  }

  Future<void> _startListening() async {
    final ok = await _speech.init();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _speech.lastInitError ?? _speech.unsupportedReason ?? 'No se pudo iniciar el reconocimiento de voz.',
          ),
        ),
      );
      return;
    }

    await _speech.startListening(
      onResult: (text, isFinal) {
        final normalized = _collapseDuplicatedChunk(text);
        if (isFinal) {
          if (normalized.isNotEmpty) {
            _dictationCommittedText = _mergeDictationText(_dictationCommittedText, normalized);
          }
          _dictationCurrentChunk = '';
        } else {
          _dictationCurrentChunk = normalized;
        }

        _syncTranscriptionControllerFromDictation();
        setState(() {});
      },
      onListeningStateChanged: (listening) {
        if (!mounted) return;
        setState(() => _isListening = listening);
      },
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de voz: $message')),
        );
      },
    );
  }

  Future<void> _pauseListeningAndProcess() async {
    if (_isListening) {
      await _speech.stopListening();
      if (!mounted) return;
      setState(() => _isListening = false);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    _flushPendingDictationChunk();

    final fullText = _normalizeDictationText(_transcriptionController.text);
    if (fullText.isEmpty) return;

    final previousProcessed = _normalizeDictationText(_lastProcessedTranscription);
    final fullLower = fullText.toLowerCase();
    final processedLower = previousProcessed.toLowerCase();

    final newChunk = previousProcessed.isNotEmpty && fullLower.startsWith(processedLower)
        ? fullText.substring(previousProcessed.length).trim()
        : fullText;

    if (newChunk.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay texto nuevo para procesar.')),
      );
      return;
    }

    final appliedNewChunk = await _previewParsedTreatments(newChunk);
    if (!mounted) return;
    if (appliedNewChunk) {
      _lastProcessedTranscription = fullText;
      return;
    }

    if (newChunk != fullText) {
      final appliedFullText = await _previewParsedTreatments(fullText);
      if (!mounted || !appliedFullText) return;
      _lastProcessedTranscription = fullText;
    }
  }

  String _normalizeDictationText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _collapseDuplicatedChunk(String value) {
    final normalized = _normalizeDictationText(value);
    if (normalized.isEmpty) return normalized;

    final words = normalized.split(' ');
    if (words.length.isEven) {
      final half = words.length ~/ 2;
      final first = words.take(half).join(' ');
      final second = words.skip(half).join(' ');
      if (first.toLowerCase() == second.toLowerCase()) {
        return first;
      }
    }

    return normalized;
  }

  String _mergeDictationText(String base, String addition) {
    final left = _normalizeDictationText(base);
    final right = _collapseDuplicatedChunk(addition);
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;

    final leftLower = left.toLowerCase();
    final rightLower = right.toLowerCase();

    if (leftLower == rightLower) return left;
    if (leftLower.endsWith(rightLower)) return left;
    if (rightLower.endsWith(leftLower)) return right;

    final maxOverlap = left.length < right.length ? left.length : right.length;
    for (var i = maxOverlap; i > 0; i--) {
      final leftSuffix = leftLower.substring(leftLower.length - i);
      final rightPrefix = rightLower.substring(0, i);
      if (leftSuffix == rightPrefix) {
        return _normalizeDictationText('$left${right.substring(i)}');
      }
    }

    return '$left $right';
  }

  void _syncTranscriptionControllerFromDictation() {
    final composed = _mergeDictationText(_dictationCommittedText, _dictationCurrentChunk);
    if (_transcriptionController.text == composed) return;
    _transcriptionController.text = composed;
    _transcriptionController.selection = TextSelection.collapsed(offset: composed.length);
  }

  void _flushPendingDictationChunk() {
    if (_dictationCurrentChunk.trim().isEmpty) return;
    _dictationCommittedText = _mergeDictationText(_dictationCommittedText, _dictationCurrentChunk);
    _dictationCurrentChunk = '';
    _syncTranscriptionControllerFromDictation();
  }

  void _resetDictationBuffersFromCurrentText() {
    _dictationCommittedText = _transcriptionController.text.trim();
    _dictationCurrentChunk = '';
  }

  Future<bool> _previewParsedTreatments(String text) async {
    final parsed = await _parser.parseTranscriptionSmart(
      transcribedText: text,
      availableTreatments: _treatments,
    );

    if (!mounted) return false;

    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se detectaron tratamientos automáticamente. Puedes añadirlos manualmente. ${_buildParseStatusHint()}',
          ),
        ),
      );
      return false;
    }

    final editable = parsed.map(_EditableParsedTreatment.fromParsed).toList();
    var appliedChanges = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final validCount = editable.where((item) => item.quantity > 0).length;
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.8,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: const Text('Interpretación detectada'),
                    subtitle: Text('$validCount líneas listas para aplicar · toca o usa editar'),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () async {
                        final created = await _showParsedLineDialog();
                        if (created == null) return;
                        setSheetState(() => editable.add(created));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir'),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: editable.isEmpty
                        ? const Center(child: Text('No hay líneas para aplicar. Añade una nueva.'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            itemCount: editable.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final item = editable[index];
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  onTap: () async {
                                    final edited = await _showParsedLineDialog(initial: item);
                                    if (edited == null) return;
                                    setSheetState(() => editable[index] = edited);
                                  },
                                  leading: const Icon(Icons.medical_services_outlined),
                                  title: Text(item.treatment.name),
                                  subtitle: Text(
                                    _formatPieceLabel(item.toothCode),
                                  ),
                                  trailing: SizedBox(
                                    width: 130,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            setSheetState(() {
                                              if (item.quantity > 1) {
                                                item.quantity -= 1;
                                              } else {
                                                editable.removeAt(index);
                                              }
                                            });
                                          },
                                          icon: const Icon(Icons.remove_circle_outline),
                                        ),
                                        Text('x${item.quantity}'),
                                        IconButton(
                                          onPressed: () => setSheetState(() => item.quantity += 1),
                                          icon: const Icon(Icons.add_circle_outline),
                                        ),
                                        IconButton(
                                          onPressed: () async {
                                            final edited = await _showParsedLineDialog(initial: item);
                                            if (edited == null) return;
                                            setSheetState(() => editable[index] = edited);
                                          },
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          onPressed: () => setSheetState(() => editable.removeAt(index)),
                                          icon: const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: editable.isEmpty
                                ? null
                                : () {
                                    final toApply = editable
                                        .where((item) => item.quantity > 0)
                                        .map((item) => item.toParsedTreatment())
                                        .toList();
                                    if (toApply.isEmpty) return;
                                    appliedChanges = true;
                                    Navigator.pop(context);
                                    _commitParsedTreatments(toApply);
                                  },
                            icon: const Icon(Icons.playlist_add_check_circle_outlined),
                            label: const Text('Aplicar cambios'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    return appliedChanges;
  }

  Future<_EditableParsedTreatment?> _showParsedLineDialog({
    _EditableParsedTreatment? initial,
  }) async {
    if (_treatments.isEmpty) return null;

    Treatment selectedTreatment = initial?.treatment ?? _treatments.first;
    final quantityController = TextEditingController(text: (initial?.quantity ?? 1).toString());
    final toothController = TextEditingController(text: initial?.toothCode ?? '');

    final result = await showDialog<_EditableParsedTreatment>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(initial == null ? 'Añadir línea' : 'Editar línea'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Treatment>(
                  initialValue: selectedTreatment,
                  items: _treatments
                      .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedTreatment = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Tratamiento',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: toothController,
                  decoration: const InputDecoration(
                    labelText: 'Pieza (opcional)',
                    hintText: 'X, 21, 11-13, +, -',
                    helperText: 'X=general · NN=pieza · NN-NN=sector · +=arcada sup · -=arcada inf',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text.trim()) ?? 1;
              if (qty <= 0) return;
              final pieceRaw = toothController.text.trim();
              final piece = _normalizePieceCodeForTreatment(selectedTreatment, pieceRaw);
              if (pieceRaw.isNotEmpty && piece == null) return;
              Navigator.pop(
                context,
                _EditableParsedTreatment(
                  treatment: selectedTreatment,
                  quantity: qty,
                  toothCode: piece,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    return result;
  }

  void _commitParsedTreatments(List<ParsedTreatment> parsed) {
    setState(() {
      for (final item in parsed) {
        final detectedTooth = _normalizePieceCodeForTreatment(
          item.treatment,
          _extractPieceCode(item.note),
        );
        final normalizedNote = _buildNoteForTreatmentCode(item.treatment, detectedTooth);
        final index = _lines.indexWhere(
          (line) => line.treatment.id == item.treatment.id && line.toothCode == detectedTooth,
        );

        if (index == -1) {
          _lines.add(
            EditableEstimateLine(
              treatment: item.treatment,
              quantity: item.quantity,
              unitPrice: item.treatment.price,
              note: normalizedNote ?? item.note,
              toothCode: detectedTooth,
            ),
          );
        } else {
          _lines[index].quantity += item.quantity;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se aplicaron ${parsed.length} líneas detectadas. ${_buildParseStatusHint()}')),
    );
  }

  String _buildParseStatusHint() {
    final sourceText = switch (_parser.lastParseSource) {
      ParseSource.localOnly => 'Fuente: parser local',
    };
    return sourceText;
  }

  String? _extractPieceCode(String? note) {
    if (note == null) return null;
    final normalizedNote = note.trim().toLowerCase();
    if (normalizedNote.startsWith('arcada superior')) return '+';
    if (normalizedNote.startsWith('arcada inferior')) return '-';
    if (normalizedNote.startsWith('general')) return 'X';

    final raw = note
        .replaceFirst(RegExp(r'^\s*(?:pieza|sector|arcada\s+superior|arcada\s+inferior|general)\s*', caseSensitive: false), '')
        .trim();
    return _normalizePieceCode(raw);
  }

  String _formatPieceLabel(String? pieceCode) {
    final value = _normalizePieceCode(pieceCode);
    if (value == null) return 'Pieza: sin asignar';
    if (value == 'X') return 'Pieza: general (X)';
    if (value == '+') return 'Pieza: arcada superior (+)';
    if (value == '-') return 'Pieza: arcada inferior (-)';
    if (value.contains('-')) return 'Pieza: sector $value';
    return 'Pieza: $value';
  }

  String? _normalizePieceCode(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return null;
    if (value == 'X') return 'X';
    if (value == '+' || value == '-') return value;

    if (RegExp(r'^\d{2}$').hasMatch(value)) {
      return value;
    }

    final compact = value.replaceAll(' ', '');
    final rangeMatch = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(compact);
    if (rangeMatch != null) {
      final start = rangeMatch.group(1)!;
      final end = rangeMatch.group(2)!;
      return '$start-$end';
    }

    return null;
  }

  void _addManualTreatment() {
    if (_selectedManualTreatment == null) return;
    final qty = int.tryParse(_manualQtyController.text.trim()) ?? 1;
    if (qty <= 0) return;

    setState(() {
      _lines.add(
        EditableEstimateLine(
          treatment: _selectedManualTreatment!,
          quantity: qty,
          unitPrice: _selectedManualTreatment!.price,
        ),
      );
    });
  }

  Future<void> _createTreatmentInline() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    var selectedPieceType = 'pieza';

    final created = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nuevo tratamiento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedPieceType,
                  items: const [
                    DropdownMenuItem(value: 'pieza', child: Text('Por pieza')),
                    DropdownMenuItem(value: 'sector', child: Text('Por sector')),
                    DropdownMenuItem(value: 'arcada', child: Text('Por arcada')),
                    DropdownMenuItem(value: 'general', child: Text('General')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedPieceType = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Aplica a',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );

    if (created != true) return;

    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || price == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y precio válidos son obligatorios.')),
      );
      return;
    }

    final insertedId = await _db.insertTreatment(
      Treatment(
        name: name,
        price: price,
        colorHex: '6C757D',
        iconKey: 'generic',
        pieceType: selectedPieceType,
      ),
      doctorId: widget.activeDoctorId!,
    );

    final treatments = await _db.getTreatments(doctorId: widget.activeDoctorId);
    Treatment? selected;
    for (final treatment in treatments) {
      if (treatment.id == insertedId) {
        selected = treatment;
        break;
      }
    }
    selected ??= treatments.where((item) => item.name.trim().toLowerCase() == name.toLowerCase()).firstOrNull;

    if (!mounted) return;
    setState(() {
      _treatments = treatments;
      _selectedManualTreatment = selected ?? (treatments.isNotEmpty ? treatments.first : null);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tratamiento "$name" creado.')),
    );
  }

  void _addTreatmentFromOdontogram(Treatment treatment, String toothCode) {
    final index = _lines.indexWhere(
      (line) => line.treatment.id == treatment.id && line.toothCode == toothCode,
    );

    setState(() {
      if (index == -1) {
        _lines.add(
          EditableEstimateLine(
            treatment: treatment,
            quantity: 1,
            unitPrice: treatment.price,
            toothCode: toothCode,
            note: 'Pieza $toothCode',
          ),
        );
      } else {
        _lines[index].quantity += 1;
      }
    });
  }

  Future<void> _saveEstimate({bool exportPdfAfterSave = false, bool popAfterSave = true}) async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona o crea un paciente antes de guardar.')),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un tratamiento.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final details = _lines
          .map(
            (line) => EstimateDetail(
              estimateId: widget.editingEstimateId ?? 0,
              treatmentId: line.treatment.id!,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
              toothCode: line.toothCode,
            ),
          )
          .toList();

      int estimateId;
      if (widget.editingEstimateId == null) {
        estimateId = await _db.insertEstimate(
          patientId: _selectedPatientId!,
          date: _selectedDate,
          details: details,
          doctorId: widget.activeDoctorId,
        );
      } else {
        await _db.updateEstimate(
          estimateId: widget.editingEstimateId!,
          patientId: _selectedPatientId!,
          date: _selectedDate,
          details: details,
          doctorId: widget.activeDoctorId,
        );
        estimateId = widget.editingEstimateId!;
      }

      if (exportPdfAfterSave) {
        await _exportPdfForEstimate(estimateId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exportPdfAfterSave
                ? 'Presupuesto guardado y PDF generado correctamente.'
                : 'Presupuesto guardado correctamente.',
          ),
        ),
      );
      if (popAfterSave) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el presupuesto: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() {
        _selectedDate = DateTime(
          selected.year,
          selected.month,
          selected.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isListening && _dictationCurrentChunk.isNotEmpty) {
      _flushPendingDictationChunk();
    }

    final money = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final total = _lines.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final sortedByUse = [..._treatments]
      ..sort((a, b) {
        final aUsage = a.id == null ? 0 : (_treatmentUsageByDoctor[a.id!] ?? 0);
        final bUsage = b.id == null ? 0 : (_treatmentUsageByDoctor[b.id!] ?? 0);
        final usageComparison = bUsage.compareTo(aUsage);
        if (usageComparison != 0) return usageComparison;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final suggested = sortedByUse.take(8).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingEstimateId == null ? 'Nuevo presupuesto' : 'Editar presupuesto'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveEstimate,
                  icon: const Icon(Icons.save),
                  label: Text(_saving ? 'Guardando...' : 'Guardar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _saveEstimate(exportPdfAfterSave: true, popAfterSave: false),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(_saving ? 'Guardando...' : 'Guardar + PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionCard(
              title: 'Paciente y fecha',
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey(_selectedPatientId),
                    initialValue: _selectedPatientId,
                    items: _patients
                        .map((patient) => DropdownMenuItem(value: patient.id, child: Text(patient.name)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedPatientId = value),
                    decoration: const InputDecoration(
                      labelText: 'Paciente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newPatientController,
                          decoration: const InputDecoration(
                            labelText: 'Nuevo paciente',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _createPatient, child: const Text('Crear')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 20),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                      const Spacer(),
                      TextButton(onPressed: _pickDate, child: const Text('Cambiar')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _SectionCard(
              title: 'Dictado por voz',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_speech.isSupportedPlatform)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _speech.unsupportedReason ??
                                    'El reconocimiento de voz no está disponible en esta plataforma.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isListening ? null : _startListening,
                          icon: const Icon(Icons.mic),
                          label: const Text('Iniciar grabación'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isListening || _transcriptionController.text.trim().isNotEmpty
                              ? _pauseListeningAndProcess
                              : null,
                          icon: const Icon(Icons.pause_circle_outline),
                          label: const Text('Pausar y previsualizar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showTranscriptionPanel = !_showTranscriptionPanel),
                      icon: Icon(_showTranscriptionPanel ? Icons.visibility_off : Icons.visibility),
                      label: Text(_showTranscriptionPanel ? 'Ocultar transcripción' : 'Mostrar transcripción'),
                    ),
                  ),
                  if (_showTranscriptionPanel) ...[
                    TextField(
                      controller: _transcriptionController,
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (_) {
                        if (!_isListening) {
                          _resetDictationBuffersFromCurrentText();
                        }
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Texto transcrito (editable)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Limpiar transcripción',
                          onPressed: _transcriptionController.text.trim().isEmpty
                              ? null
                              : () {
                                  _transcriptionController.clear();
                                  _resetDictationBuffersFromCurrentText();
                                  _lastProcessedTranscription = '';
                                  setState(() {});
                                },
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_isListening)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Grabando... pulsa "Pausar y previsualizar" para revisar y editar tratamientos.'),
                    ),
                  if (!_isListening && _transcriptionController.text.trim().isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Transcripción lista. Puedes editarla o procesarla de nuevo.'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _SectionCard(
              title: 'Odontograma',
              child: OdontogramWidget(
                lines: _lines,
                treatments: _treatments,
                onAddTreatmentToTooth: _addTreatmentFromOdontogram,
                onRemoveTreatmentFromTooth: _removeTreatmentFromOdontogram,
              ),
            ),
            const SizedBox(height: 10),
            _SectionCard(
              title: null,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded: _showManualTreatmentPanel,
                  onExpansionChanged: (expanded) {
                    setState(() => _showManualTreatmentPanel = expanded);
                  },
                  title: const Text('Añadir tratamiento manual'),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _createTreatmentInline,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Crear tratamiento'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: suggested
                          .map(
                            (item) => ActionChip(
                              label: Text(item.name),
                              onPressed: () {
                                _selectedManualTreatment = item;
                                _addManualTreatment();
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Treatment>(
                            key: ValueKey(_selectedManualTreatment?.id),
                            initialValue: _selectedManualTreatment,
                            items: _treatments
                                .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
                                .toList(),
                            onChanged: (value) => setState(() => _selectedManualTreatment = value),
                            decoration: const InputDecoration(
                              labelText: 'Tratamiento',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 86,
                          child: TextField(
                            controller: _manualQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cant.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: _addManualTreatment, child: const Text('Añadir')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _SectionCard(
              title: 'Resumen del presupuesto',
              child: _lines.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No hay tratamientos añadidos todavía.'),
                    )
                  : Column(
                      children: _lines.asMap().entries.map((entry) {
                        final index = entry.key;
                        final line = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            onTap: () => _showEditLineDialog(index),
                            title: Text(line.treatment.name),
                            subtitle: Text(_formatPieceLabel(line.toothCode)),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('x${line.quantity} · ${money.format(line.unitPrice)}'),
                                Text(money.format(line.lineTotal)),
                              ],
                            ),
                            leading: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() => _lines.removeAt(index)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              'Total final: ${money.format(total)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditLineDialog(int index) async {
    final line = _lines[index];
    final qtyController = TextEditingController(text: line.quantity.toString());
    final priceController = TextEditingController(text: line.unitPrice.toStringAsFixed(2));
    final toothController = TextEditingController(text: line.toothCode ?? '');

    await showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Editar ${line.treatment.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio unitario'),
              ),
              TextField(
                controller: toothController,
                decoration: const InputDecoration(
                  labelText: 'Pieza (X, 21, 11-13, +, -)',
                  helperText: 'X=general · NN=pieza · NN-NN=sector · +=sup · -=inf',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final quantity = int.tryParse(qtyController.text) ?? line.quantity;
                final unitPrice = double.tryParse(priceController.text.replaceAll(',', '.')) ?? line.unitPrice;
                final pieceRaw = toothController.text.trim();
                final piece = _normalizePieceCodeForTreatment(line.treatment, pieceRaw);
                if (pieceRaw.isNotEmpty && piece == null) return;

                setState(() {
                  line.quantity = quantity;
                  line.unitPrice = unitPrice;
                  line.toothCode = piece;
                  line.note = _buildNoteForTreatmentCode(line.treatment, piece);
                });
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}

class _EditableParsedTreatment {
  Treatment treatment;
  int quantity;
  String? toothCode;

  _EditableParsedTreatment({
    required this.treatment,
    required this.quantity,
    this.toothCode,
  });

  factory _EditableParsedTreatment.fromParsed(ParsedTreatment parsed) {
    final tooth = _extractPieceCodeFromNote(parsed.note);
    return _EditableParsedTreatment(
      treatment: parsed.treatment,
      quantity: parsed.quantity,
      toothCode: tooth,
    );
  }

  ParsedTreatment toParsedTreatment() {
    final piece = _normalizePieceCodeForTreatmentValue(treatment, toothCode);
    final pieceType = (treatment.pieceType ?? 'pieza').trim().toLowerCase();
    final note = switch (piece) {
      null => null,
      _ when pieceType == 'general' => 'General',
      final value when pieceType == 'arcada' => value == '+' ? 'Arcada superior' : 'Arcada inferior',
      final value when value.contains('-') => 'Sector $value',
      _ => 'Pieza $piece',
    };

    return ParsedTreatment(
      treatment: treatment,
      quantity: quantity,
      note: note,
    );
  }

  static String? _extractPieceCodeFromNote(String? note) {
    if (note == null) return null;
    final normalizedNote = note.trim().toLowerCase();
    if (normalizedNote.startsWith('arcada superior')) return '+';
    if (normalizedNote.startsWith('arcada inferior')) return '-';
    if (normalizedNote.startsWith('general')) return 'X';

    final raw = note
        .replaceFirst(RegExp(r'^\s*(?:pieza|sector|arcada\s+superior|arcada\s+inferior|general)\s*', caseSensitive: false), '')
        .trim();
    return _normalizePieceCodeValue(raw);
  }

  static String? _normalizePieceCodeForTreatmentValue(Treatment treatment, String? rawCode) {
    final pieceType = (treatment.pieceType ?? 'pieza').trim().toLowerCase();
    final code = _normalizePieceCodeValue(rawCode);

    return switch (pieceType) {
      'general' => 'X',
      'arcada' => _normalizeArcadaCodeValue(code),
      'sector' => _normalizeSectorCodeValue(code),
      _ => _normalizePiezaCodeValue(code),
    };
  }

  static String? _normalizePiezaCodeValue(String? code) {
    if (code == null) return null;
    if (RegExp(r'^\d{2}$').hasMatch(code)) return code;
    return null;
  }

  static String? _normalizeSectorCodeValue(String? code) {
    if (code == null) return null;
    if (RegExp(r'^\d{2}-\d{2}$').hasMatch(code)) {
      final parts = code.split('-');
      final start = parts[0];
      final end = parts[1];
      if (start[0] != end[0]) return null;
      return int.parse(start) <= int.parse(end) ? '$start-$end' : '$end-$start';
    }
    if (RegExp(r'^\d{2}$').hasMatch(code)) return code;
    return null;
  }

  static String? _normalizeArcadaCodeValue(String? code) {
    if (code == null) return null;
    if (code == '+' || code == '-') return code;
    if (RegExp(r'^\d{2}$').hasMatch(code)) {
      return (code.startsWith('1') || code.startsWith('2')) ? '+' : '-';
    }
    if (RegExp(r'^\d{2}-\d{2}$').hasMatch(code)) {
      final parts = code.split('-');
      final start = parts[0];
      final end = parts[1];
      final isUpper = (start.startsWith('1') || start.startsWith('2')) && (end.startsWith('1') || end.startsWith('2'));
      final isLower = (start.startsWith('3') || start.startsWith('4')) && (end.startsWith('3') || end.startsWith('4'));
      if (isUpper) return '+';
      if (isLower) return '-';
    }
    return null;
  }

  static String? _normalizePieceCodeValue(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return null;
    if (value == 'X') return 'X';
    if (value == '+' || value == '-') return value;
    if (RegExp(r'^\d{2}$').hasMatch(value)) return value;

    final compact = value.replaceAll(' ', '');
    final rangeMatch = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(compact);
    if (rangeMatch != null) {
      return '${rangeMatch.group(1)!}-${rangeMatch.group(2)!}';
    }

    return null;
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title!.trim().isNotEmpty) ...[
              Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
