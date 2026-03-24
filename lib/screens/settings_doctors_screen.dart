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
  static const _doctorColorPalette = [
    '1D3557',
    '2A9D8F',
    'E76F51',
    '6D597A',
    '3A86FF',
    '2D6A4F',
    'F4A261',
    'C1121F',
  ];

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
    String selectedColor = doctor?.colorHex ?? _doctorColorPalette.first;
    if (!_doctorColorPalette.contains(selectedColor)) {
      selectedColor = _doctorColorPalette.first;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(doctor == null ? 'Nuevo doctor' : 'Editar doctor'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Color del perfil'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _doctorColorPalette
                        .map(
                          (colorHex) => ChoiceChip(
                            selected: selectedColor == colorHex,
                            onSelected: (_) => setDialogState(() => selectedColor = colorHex),
                            showCheckmark: false,
                            avatar: CircleAvatar(
                              radius: 8,
                              backgroundColor: _parseHex(colorHex),
                            ),
                            label: const SizedBox(width: 4, height: 4),
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
            },
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
      await _db.insertDoctor(Doctor(name: name, colorHex: selectedColor));
    } else {
      await _db.updateDoctor(
        Doctor(
          id: doctor.id,
          name: name,
          isAdmin: doctor.isAdmin,
          colorHex: selectedColor,
        ),
      );
    }

    await _load();
  }

  Future<void> _deleteDoctor(Doctor doctor) async {
    if (doctor.isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cuenta Admin no se puede eliminar.')),
      );
      return;
    }

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
                          leading: CircleAvatar(
                            backgroundColor: _parseHex(doctor.colorHex),
                            child: const Icon(Icons.medical_services_outlined, color: Colors.white),
                          ),
                          title: Text(doctor.name),
                          subtitle: doctor.isAdmin ? const Text('Cuenta general Admin') : null,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: () => _openDoctorDialog(doctor: doctor),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: doctor.isAdmin ? null : () => _deleteDoctor(doctor),
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

  Color _parseHex(String? hex) {
    final normalized = (hex ?? '').trim().replaceAll('#', '');
    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
      return Theme.of(context).colorScheme.primary;
    }
    return Color(int.parse('FF$normalized', radix: 16));
  }
}
