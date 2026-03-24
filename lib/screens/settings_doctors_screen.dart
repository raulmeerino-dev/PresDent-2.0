import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/doctor.dart';

class SettingsDoctorsScreen extends StatefulWidget {
  const SettingsDoctorsScreen({super.key});

  @override
  State<SettingsDoctorsScreen> createState() => _SettingsDoctorsScreenState();
}

class _SettingsDoctorsScreenState extends State<SettingsDoctorsScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<Doctor> _doctors = [];
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
    final rows = await _db.getDoctors(query: _searchController.text);
    if (!mounted) return;
    setState(() {
      _doctors = rows;
      _loading = false;
    });
  }

  Future<void> _openDoctorDialog({Doctor? doctor}) async {
    final nameController = TextEditingController(text: doctor?.name ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(doctor == null ? 'Nuevo doctor' : 'Editar doctor'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre'),
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

    if (doctor == null) {
      await _db.insertDoctor(Doctor(name: name));
    } else {
      await _db.updateDoctor(Doctor(id: doctor.id, name: name));
    }

    await _load();
  }

  Future<void> _deleteDoctor(Doctor doctor) async {
    final patientsCount = await _db.countPatientsForDoctor(doctor.id!);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar doctor'),
          content: Text(
            patientsCount > 0
                ? 'Este doctor tiene $patientsCount pacientes vinculados. Se desvincularán al eliminarlo. ¿Continuar?'
                : '¿Eliminar ${doctor.name}?',
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

    await _db.deleteDoctor(doctor.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctores')),
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
                      hintText: 'Buscar doctor',
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
                  onPressed: () => _openDoctorDialog(),
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
                    itemCount: _doctors.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final doctor = _doctors[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.medical_services_outlined)),
                          title: Text(doctor.name),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: () => _openDoctorDialog(doctor: doctor),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _deleteDoctor(doctor),
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
