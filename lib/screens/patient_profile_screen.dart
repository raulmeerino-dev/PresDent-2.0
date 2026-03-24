import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/estimate.dart';
import '../models/patient.dart';
import 'create_estimate_screen.dart';
import 'estimate_detail_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  final int patientId;
  final String patientName;
  final String? doctorName;

  const PatientProfileScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.doctorName,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _db = DatabaseHelper.instance;

  bool _loading = true;
  bool _savingPatient = false;
  Patient? _patient;
  List<EstimateSummary> _estimates = [];
  final Map<int, List<EstimateDetailView>> _detailsByEstimate = {};
  final Set<int> _loadingDetails = {};
  final Map<int, String> _detailsErrors = {};

  Future<void> _load() async {
    setState(() => _loading = true);
    final rowsFuture = _db.getEstimates(
      patientId: widget.patientId,
      orderBy: 'fecha',
      descending: true,
    );
    final patientFuture = _db.getPatientById(widget.patientId);
    final rows = await rowsFuture;
    final patient = await patientFuture;
    if (!mounted) return;
    setState(() {
      _estimates = rows;
      _patient = patient;
      _loading = false;
    });
  }

  Future<void> _openEditPatientDialog() async {
    final current = _patient;
    if (current == null) return;

    final phoneController = TextEditingController(text: current.phone ?? '');
    final notesController = TextEditingController(text: current.notes ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Datos del paciente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _savingPatient ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: _savingPatient
                  ? null
                  : () async {
                      setState(() => _savingPatient = true);
                      await _db.updatePatient(
                        Patient(
                          id: current.id,
                          name: current.name,
                          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        ),
                      );
                      if (!mounted) return;
                      setState(() => _savingPatient = false);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      await _load();
                    },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadEstimateDetails(int estimateId) async {
    if (_detailsByEstimate.containsKey(estimateId) || _loadingDetails.contains(estimateId)) return;

    setState(() {
      _loadingDetails.add(estimateId);
      _detailsErrors.remove(estimateId);
    });

    try {
      final details = await _db.getEstimateDetails(estimateId);
      if (!mounted) return;
      setState(() {
        _detailsByEstimate[estimateId] = details;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detailsErrors[estimateId] = 'No se pudo cargar el resumen.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetails.remove(estimateId);
        });
      }
    }
  }

  Widget _buildEstimateMiniSummary(int estimateId, NumberFormat money) {
    final error = _detailsErrors[estimateId];
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(error, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_loadingDetails.contains(estimateId)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }

    final details = _detailsByEstimate[estimateId];
    if (details == null || details.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text('Sin líneas para mostrar.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Desglose rápido (${details.length} líneas):', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...details.take(5).map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.toothCode == null
                          ? '${d.treatmentName} x${d.quantity}'
                          : '${d.treatmentName} (${d.toothCode}) x${d.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(money.format(d.lineTotal)),
                ],
              ),
            ),
          ),
          if (details.length > 5)
            Text(
              '+${details.length - 5} líneas más (ver detalle para todo)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final date = DateFormat('dd/MM/yyyy HH:mm');
    final totalAccumulated = _estimates.fold<double>(0, (sum, item) => sum + item.total);
    final patientName = _patient?.name ?? widget.patientName;
    final patientPhone = _patient?.phone;
    final patientNotes = _patient?.notes;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de paciente')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(patientName, style: Theme.of(context).textTheme.titleLarge),
                              ),
                              IconButton(
                                onPressed: _patient == null ? null : _openEditPatientDialog,
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Editar datos',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Doctor: ${widget.doctorName ?? 'Sin asignar'}'),
                          Text('Teléfono: ${patientPhone == null || patientPhone.isEmpty ? 'Sin teléfono' : patientPhone}'),
                          if (patientNotes != null && patientNotes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Notas: $patientNotes'),
                            ),
                          Text('Presupuestos: ${_estimates.length}'),
                          Text('Total acumulado: ${money.format(totalAccumulated)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_estimates.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('Este paciente no tiene presupuestos todavía.'),
                      ),
                    )
                  else
                    ..._estimates.map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          onExpansionChanged: (expanded) {
                            if (expanded) {
                              _loadEstimateDetails(item.id);
                            }
                          },
                          title: Text('Presupuesto #${item.id} · ${money.format(item.total)}'),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(date.format(item.date)),
                          ),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => EstimateDetailScreen(estimateId: item.id),
                                        ),
                                      );
                                      await _load();
                                    },
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text('Ver detalle'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => CreateEstimateScreen(editingEstimateId: item.id),
                                        ),
                                      );
                                      await _load();
                                    },
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Editar'),
                                  ),
                                ),
                              ],
                            ),
                            _buildEstimateMiniSummary(item.id, money),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
