import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/treatment.dart';

class SettingsTreatmentsScreen extends StatefulWidget {
  const SettingsTreatmentsScreen({super.key});

  @override
  State<SettingsTreatmentsScreen> createState() => _SettingsTreatmentsScreenState();
}

class _SettingsTreatmentsScreenState extends State<SettingsTreatmentsScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  static const _iconOptions = [
    'caries',
    'extraction',
    'implant',
    'cleaning',
    'crown',
    'root',
    'whitening',
    'restoration',
    'prosthesis',
    'ortho',
    'guard',
    'xray',
    'scan',
    'anesthesia',
    'surgery',
    'pediatric',
    'periodontics',
    'bridge',
    'veneer',
    'retainer',
    'occlusion',
    'consult',
    'emergency',
    'hygiene',
    'diagnosis',
    'sealant',
    'esthetic',
    'maintenance',
    'sedation',
    'sensitivity',
    'prosthesis_fixed',
    'prosthesis_removable',
    'sutures',
    'planning',
    'payment',
    'lab',
    'followup',
    'generic',
  ];

  static const _pieceTypeOptions = [
    'general',
    'pieza',
    'sector',
    'arcada',
  ];

  static const _colorPalette = [
    '0E7C7B',
    '3A86FF',
    'D90429',
    '8338EC',
    '2A9D8F',
    '8ECAE6',
    '6D597A',
    '4D908E',
    'F77F00',
    '2B9348',
    '577590',
    '6C757D',
  ];

  List<Treatment> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _normalizeColorHex(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll('#', '').trim().toUpperCase();
    if (cleaned.length != 6) return null;
    if (int.tryParse(cleaned, radix: 16) == null) return null;
    return cleaned;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _db.getTreatments(query: _searchController.text);
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _openTreatmentDialog({Treatment? treatment}) async {
    final nameController = TextEditingController(text: treatment?.name ?? '');
    final priceController = TextEditingController(
      text: treatment?.price.toStringAsFixed(2) ?? '',
    );

    String selectedIcon = treatment?.iconKey ?? 'generic';
    if (!_iconOptions.contains(selectedIcon)) {
      selectedIcon = 'generic';
    }

    String selectedPieceType = treatment?.pieceType ?? 'pieza';
    if (!_pieceTypeOptions.contains(selectedPieceType)) {
      selectedPieceType = 'pieza';
    }

    String selectedColor = _normalizeColorHex(treatment?.colorHex) ?? _defaultColorForIcon(selectedIcon);
    if (!_colorPalette.contains(selectedColor)) {
      selectedColor = _colorPalette.first;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(treatment == null ? 'Nuevo tratamiento' : 'Editar tratamiento'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Precio (€)'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Icono'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _iconOptions
                          .map(
                            (iconKey) => ChoiceChip(
                              selected: selectedIcon == iconKey,
                              onSelected: (_) => setDialogState(() => selectedIcon = iconKey),
                              avatar: Icon(_iconData(iconKey), size: 16),
                              label: Text(_iconLabel(iconKey)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPieceType,
                      items: _pieceTypeOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_pieceTypeLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedPieceType = value);
                      },
                      decoration: const InputDecoration(labelText: 'Aplica a'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Color'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _colorPalette
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
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _parseHex(selectedColor),
                        child: Icon(_iconData(selectedIcon), color: Colors.white, size: 18),
                      ),
                      title: const Text('Vista previa'),
                      subtitle: Text(
                        '${nameController.text.trim().isEmpty ? 'Tratamiento' : nameController.text.trim()} · ${_pieceTypeLabel(selectedPieceType)}',
                      ),
                    ),
                  ],
                ),
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
    final price = double.tryParse(priceController.text.replaceAll(',', '.'));
    if (name.isEmpty || price == null) return;

    final normalizedColor = selectedColor;
    final iconKey = selectedIcon == 'generic' ? null : selectedIcon;

    if (treatment == null) {
      await _db.insertTreatment(
        Treatment(
          name: name,
          price: price,
          colorHex: normalizedColor,
          iconKey: iconKey,
          pieceType: selectedPieceType,
        ),
      );
    } else {
      await _db.updateTreatment(
        Treatment(
          id: treatment.id,
          name: name,
          price: price,
          colorHex: normalizedColor,
          iconKey: iconKey,
          pieceType: selectedPieceType,
        ),
      );
    }

    await _load();
  }

  Future<void> _deleteTreatment(Treatment treatment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar tratamiento'),
        content: Text('¿Eliminar ${treatment.name}?'),
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
      ),
    );

    if (confirmed != true) return;

    await _db.deleteTreatment(treatment.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tratamientos')),
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
                      hintText: 'Buscar tratamiento',
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
                  onPressed: () => _openTreatmentDialog(),
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
                    itemCount: _items.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _parseHex(item.colorHex) ?? Theme.of(context).colorScheme.primary,
                            child: Icon(_iconData(item.iconKey), color: Colors.white, size: 18),
                          ),
                          title: Text(item.name),
                          subtitle: Text('€${item.price.toStringAsFixed(2)} · ${_pieceTypeLabel(item.pieceType)}'),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: () => _openTreatmentDialog(treatment: item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _deleteTreatment(item),
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

  String _iconLabel(String iconKey) {
    return switch (iconKey) {
      'caries' => 'Caries',
      'extraction' => 'Extracción',
      'implant' => 'Implante',
      'cleaning' => 'Limpieza',
      'crown' => 'Corona',
      'root' => 'Endodoncia',
      'whitening' => 'Blanqueo',
      'restoration' => 'Incrustación',
      'prosthesis' => 'Prótesis',
      'ortho' => 'Orto',
      'guard' => 'Férula',
      'xray' => 'Rx',
      'scan' => 'TAC',
      'anesthesia' => 'Anestesia',
      'surgery' => 'Cirugía',
      'pediatric' => 'Pediatría',
      'periodontics' => 'Periodoncia',
      'bridge' => 'Puente',
      'veneer' => 'Carilla',
      'retainer' => 'Retenedor',
      'occlusion' => 'Oclusión',
      'consult' => 'Consulta',
      'emergency' => 'Urgencia',
      'hygiene' => 'Higiene',
      'diagnosis' => 'Diagnóstico',
      'sealant' => 'Sellador',
      'esthetic' => 'Estética',
      'maintenance' => 'Mantenimiento',
      'sedation' => 'Sedación',
      'sensitivity' => 'Sensibilidad',
      'prosthesis_fixed' => 'Prótesis fija',
      'prosthesis_removable' => 'Prótesis removible',
      'sutures' => 'Suturas',
      'planning' => 'Planificación',
      'payment' => 'Pago',
      'lab' => 'Laboratorio',
      'followup' => 'Seguimiento',
      _ => 'Genérico',
    };
  }

  IconData _iconData(String? iconKey) {
    return switch (iconKey) {
      'caries' => Icons.circle,
      'extraction' => Icons.content_cut,
      'implant' => Icons.hardware,
      'cleaning' => Icons.cleaning_services,
      'crown' => Icons.workspace_premium,
      'root' => Icons.account_tree,
      'whitening' => Icons.brightness_5,
      'restoration' => Icons.build_circle,
      'prosthesis' => Icons.medical_services,
      'ortho' => Icons.straighten,
      'guard' => Icons.shield,
      'xray' => Icons.science,
      'scan' => Icons.document_scanner,
      'anesthesia' => Icons.vaccines,
      'surgery' => Icons.local_hospital,
      'pediatric' => Icons.child_care,
      'periodontics' => Icons.grass,
      'bridge' => Icons.view_week,
      'veneer' => Icons.auto_awesome,
      'retainer' => Icons.align_horizontal_center,
      'occlusion' => Icons.adjust,
      'consult' => Icons.medical_information,
      'emergency' => Icons.emergency,
      'hygiene' => Icons.sanitizer,
      'diagnosis' => Icons.biotech,
      'sealant' => Icons.water_drop,
      'esthetic' => Icons.auto_awesome,
      'maintenance' => Icons.event_available,
      'sedation' => Icons.airline_seat_flat,
      'sensitivity' => Icons.bolt,
      'prosthesis_fixed' => Icons.view_week,
      'prosthesis_removable' => Icons.accessibility_new,
      'sutures' => Icons.linear_scale,
      'planning' => Icons.edit_calendar,
      'payment' => Icons.payments,
      'lab' => Icons.science_outlined,
      'followup' => Icons.assignment_turned_in,
      _ => Icons.hexagon,
    };
  }

  String _pieceTypeLabel(String? value) {
    return switch (value) {
      'general' => 'General',
      'pieza' => 'Pieza',
      'sector' => 'Sector',
      'arcada' => 'Arcada',
      _ => 'Pieza',
    };
  }

  String _defaultColorForIcon(String iconKey) {
    return switch (iconKey) {
      'implant' => '0E7C7B',
      'crown' => '3A86FF',
      'extraction' => 'D90429',
      'root' => '8338EC',
      'cleaning' => '2A9D8F',
      'whitening' => '8ECAE6',
      'prosthesis' => '6D597A',
      'ortho' => '4D908E',
      'guard' => '7D8597',
      'xray' => 'ADB5BD',
      'scan' => '6C757D',
      'surgery' => '9D0208',
      'anesthesia' => '5A189A',
      'pediatric' => 'F48C06',
      'periodontics' => '2D6A4F',
      'bridge' => '355070',
      'veneer' => '4895EF',
      'retainer' => '4361EE',
      'occlusion' => '6C757D',
      'consult' => '457B9D',
      'emergency' => 'E63946',
      'hygiene' => '06D6A0',
      'diagnosis' => '577590',
      'sealant' => '00A6A6',
      'esthetic' => 'F4A261',
      'maintenance' => '2A9D8F',
      'sedation' => '5A189A',
      'sensitivity' => 'F77F00',
      'prosthesis_fixed' => '355070',
      'prosthesis_removable' => '6D597A',
      'sutures' => '9D0208',
      'planning' => '4361EE',
      'payment' => '2B9348',
      'lab' => '577590',
      'followup' => '4895EF',
      _ => '6C757D',
    };
  }

  Color? _parseHex(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll('#', '').trim();
    if (cleaned.length != 6) return null;
    final hex = int.tryParse(cleaned, radix: 16);
    if (hex == null) return null;
    return Color(0xFF000000 | hex);
  }
}
