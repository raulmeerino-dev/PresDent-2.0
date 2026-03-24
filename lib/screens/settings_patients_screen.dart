import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/patient.dart';

class SettingsPatientsScreen extends StatefulWidget {
  const SettingsPatientsScreen({super.key});

  @override
  State<SettingsPatientsScreen> createState() => _SettingsPatientsScreenState();
}

class _SettingsPatientsScreenState extends State<SettingsPatientsScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<Patient> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _db.getPatients(query: _searchController.text);
    if (!mounted) return;
    setState(() {
      _patients = rows;
      _loading = false;
    });
  }

  Future<void> _openPatientDialog({Patient? patient}) async {
    final nameController = TextEditingController(text: patient?.name ?? '');
    final phoneController = TextEditingController(text: patient?.phone ?? '');
    final notesController = TextEditingController(text: patient?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(patient == null ? 'Nuevo paciente' : 'Editar paciente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final payload = Patient(
      id: patient?.id,
      name: name,
      phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
    );

    if (patient == null) {
      await _db.insertPatient(payload);
    } else {
      await _db.updatePatient(payload);
    }

    await _load();
  }

  Future<void> _deletePatient(Patient patient) async {
    final estimateCount = await _db.countEstimatesForPatient(patient.id!);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar paciente'),
          content: Text(
            estimateCount > 0
                ? 'Este paciente tiene $estimateCount presupuestos. Se eliminarán también. ¿Continuar?'
                : '¿Eliminar ${patient.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _db.deletePatient(patient.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar paciente',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _load,
                      ),
                    ),
                    onChanged: (_) => _load(),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openPatientDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _patients.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final patient = _patients[index];
                      final subtitle = <String>[
                        if (patient.phone != null && patient.phone!.trim().isNotEmpty) patient.phone!.trim(),
                        if (patient.notes != null && patient.notes!.trim().isNotEmpty) patient.notes!.trim(),
                      ].join(' · ');

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text(patient.name),
                          subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: () => _openPatientDialog(patient: patient),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _deletePatient(patient),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
