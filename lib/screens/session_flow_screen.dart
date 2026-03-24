import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/doctor.dart';

class SessionSelection {
  final Doctor doctor;
  final int? patientId;
  final String? patientName;

  const SessionSelection({
    required this.doctor,
    this.patientId,
    this.patientName,
  });
}

class SessionFlowScreen extends StatefulWidget {
  final Widget Function(SessionSelection selection) onSessionReady;

  const SessionFlowScreen({super.key, required this.onSessionReady});

  @override
  State<SessionFlowScreen> createState() => _SessionFlowScreenState();
}

class _SessionFlowScreenState extends State<SessionFlowScreen> {
  final _db = DatabaseHelper.instance;
  final _newDoctorController = TextEditingController();
  static const _backgroundLogoAssetCandidates = [
    'assets/images/LOGOSINFONDO.png',
    'assets/images/LOGO PERFIL WHATSAPP 3.png',
    'assets/images/app_icon.png',
  ];

  List<Doctor> _doctors = [];

  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _newDoctorController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    try {
      setState(() {
        _loading = true;
        _loadError = null;
      });
      await _db.ensureDefaults();
      final doctors = await _db.getDoctors();
      setState(() {
        _doctors = doctors;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _createDoctor([String? rawName]) async {
    final name = (rawName ?? _newDoctorController.text).trim();
    if (name.isEmpty) return;
    final id = await _db.insertDoctor(Doctor(name: name));
    _newDoctorController.clear();

    final doctors = await _db.getDoctors();
    setState(() {
      _doctors = doctors;
    });

    final createdDoctor = doctors.where((d) => d.id == id).firstOrNull;
    if (createdDoctor != null && mounted) {
      _continueWithDoctor(createdDoctor);
    }
  }

  Future<void> _openCreateDoctorDialog() async {
    _newDoctorController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nuevo doctor'),
          content: TextField(
            controller: _newDoctorController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) async {
              await _createDoctor();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            decoration: const InputDecoration(
              labelText: 'Nombre del doctor',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                await _createDoctor();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  void _continueWithDoctor(Doctor doctor) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => widget.onSessionReady(
          SessionSelection(doctor: doctor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Inicio de sesión clínica')),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.06,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Image.asset(
                      _backgroundLogoAssetCandidates.first,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stackTrace) => Image.asset(
                        _backgroundLogoAssetCandidates[1],
                        fit: BoxFit.contain,
                        errorBuilder: (_, fallbackError, fallbackStackTrace) => Image.asset(
                          _backgroundLogoAssetCandidates.last,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 34),
                    const SizedBox(height: 8),
                    const Text('No se pudo cargar la sesión clínica.'),
                    const SizedBox(height: 6),
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loadDoctors,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Selecciona doctor',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toca un doctor para entrar directamente.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (_doctors.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('No hay doctores aún.'),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _openCreateDoctorDialog,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Crear primer doctor'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._doctors.map(
                    (doctor) {
                      final cardColor = isDark
                          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.92)
                          : Colors.white.withValues(alpha: 0.9);
                      final borderColor = isDark
                          ? colorScheme.outline.withValues(alpha: 0.45)
                          : colorScheme.outlineVariant.withValues(alpha: 0.5);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: borderColor),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _continueWithDoctor(doctor),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      doctor.name,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _openCreateDoctorDialog,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Crear doctor nuevo'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
