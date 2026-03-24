import 'package:flutter/material.dart';

import '../models/editable_estimate_line.dart';
import '../models/treatment.dart';

class OdontogramWidget extends StatelessWidget {
  final List<EditableEstimateLine> lines;
  final List<Treatment> treatments;
  final void Function(Treatment treatment, String toothCode) onAddTreatmentToTooth;
  final void Function(Treatment treatment, String toothCode) onRemoveTreatmentFromTooth;

  const OdontogramWidget({
    super.key,
    required this.lines,
    required this.treatments,
    required this.onAddTreatmentToTooth,
    required this.onRemoveTreatmentFromTooth,
  });

  static const _topRight = ['18', '17', '16', '15', '14', '13', '12', '11'];
  static const _topLeft = ['21', '22', '23', '24', '25', '26', '27', '28'];
  static const _bottomLeft = ['48', '47', '46', '45', '44', '43', '42', '41'];
  static const _bottomRight = ['31', '32', '33', '34', '35', '36', '37', '38'];
  static const _allTeeth = {
    ..._topRight,
    ..._topLeft,
    ..._bottomLeft,
    ..._bottomRight,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArch(context, _topRight, _topLeft),
        const SizedBox(height: 8),
        _buildArch(context, _bottomLeft, _bottomRight),
      ],
    );
  }

  Widget _buildArch(BuildContext context, List<String> left, List<String> right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const spacing = 4.0;
        const centerGap = 8.0;
        final computedWidth =
            (availableWidth - centerGap - (spacing * 15)) / 16;
        final tileWidth = computedWidth > 54 ? 54.0 : computedWidth;
        final tileHeight = tileWidth * 1.22;

        return SizedBox(
          width: availableWidth,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.contain,
            child: SizedBox(
              width: availableWidth,
              child: Row(
                children: [
                  ...left.asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(right: entry.key == left.length - 1 ? 0 : spacing),
                      child: _toothTile(
                        context,
                        entry.value,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                      ),
                    ),
                  ),
                  const SizedBox(width: centerGap),
                  ...right.asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(right: entry.key == right.length - 1 ? 0 : spacing),
                      child: _toothTile(
                        context,
                        entry.value,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _toothTile(
    BuildContext context,
    String toothCode, {
    double tileWidth = 54,
    double tileHeight = 68,
  }) {
    final toothLines = lines.where((line) => _lineAffectsTooth(line, toothCode)).toList();
    final primaryLine = toothLines.isEmpty ? null : toothLines.first;
    final uniqueTreatments = <Treatment>[
      for (final line in toothLines)
        if (!toothLines.take(toothLines.indexOf(line)).any((prev) => prev.treatment.id == line.treatment.id)) line.treatment,
    ];

    final color = toothLines.isEmpty
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : _resolveColor(primaryLine!.treatment).withValues(alpha: 0.92);
    final compact = tileWidth < 42;

    return InkWell(
      onTap: () => _openToothDialog(context, toothCode, toothLines),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: tileWidth,
        height: tileHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              toothCode,
              style: TextStyle(
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w600,
                color: toothLines.isEmpty ? Colors.black87 : Colors.white,
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
            if (toothLines.isEmpty)
              Icon(Icons.hexagon, size: compact ? 14 : 18, color: Colors.grey)
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: uniqueTreatments
                    .take(3)
                    .map(
                      (t) => Container(
                        width: compact ? 11 : 14,
                        height: compact ? 11 : 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _resolveIcon(t),
                          size: compact ? 8 : 10,
                          color: Colors.white,
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (uniqueTreatments.length > 3)
              Text(
                '+${uniqueTreatments.length - 3}',
                style: TextStyle(fontSize: compact ? 8 : 9, color: Colors.white, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openToothDialog(BuildContext context, String toothCode, List<EditableEstimateLine> toothLines) async {
    final selected = await showModalBottomSheet<Treatment>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: Column(
              children: [
                ListTile(
                  title: Text('Pieza $toothCode'),
                  subtitle: Text(
                    toothLines.isEmpty
                        ? 'Sin tratamientos asignados'
                        : 'Asignados: ${toothLines.map((e) => e.treatment.name).join(', ')}',
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    children: [
                      if (toothLines.isNotEmpty)
                        ...toothLines.map(
                          (line) {
                            final canDeleteDirectly = (line.toothCode ?? '').toUpperCase() == toothCode;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _resolveColor(line.treatment),
                                radius: 10,
                                child: Icon(_resolveIcon(line.treatment), size: 12, color: Colors.white),
                              ),
                              title: Text('${line.treatment.name} x${line.quantity}'),
                              subtitle: line.toothCode == null ? null : Text('Asignación: ${line.toothCode}'),
                              trailing: canDeleteDirectly
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        onRemoveTreatmentFromTooth(line.treatment, toothCode);
                                        Navigator.pop(context);
                                      },
                                    )
                                  : null,
                            );
                          },
                        ),
                      if (toothLines.isNotEmpty) const Divider(height: 1),
                      ...treatments.map(
                        (t) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _resolveColor(t),
                            radius: 10,
                            child: Icon(_resolveIcon(t), size: 12, color: Colors.white),
                          ),
                          title: Text(t.name),
                          onTap: () => Navigator.pop(context, t),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onAddTreatmentToTooth(selected, toothCode);
    }
  }

  bool _lineAffectsTooth(EditableEstimateLine line, String toothCode) {
    final raw = line.toothCode?.trim().toUpperCase();
    if (raw == null || raw.isEmpty) return false;

    if (raw == toothCode) return true;

    if (raw == '+') {
      return toothCode.startsWith('1') || toothCode.startsWith('2');
    }

    if (raw == '-') {
      return toothCode.startsWith('3') || toothCode.startsWith('4');
    }

    final compact = raw.replaceAll(' ', '');
    final rangeMatch = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(compact);
    if (rangeMatch == null) return false;

    final start = rangeMatch.group(1)!;
    final end = rangeMatch.group(2)!;
    if (!_allTeeth.contains(start) || !_allTeeth.contains(end) || !_allTeeth.contains(toothCode)) {
      return false;
    }

    final quadrant = start[0];
    if (end[0] != quadrant || toothCode[0] != quadrant) {
      return false;
    }

    final startNum = int.tryParse(start[1]);
    final endNum = int.tryParse(end[1]);
    final toothNum = int.tryParse(toothCode[1]);
    if (startNum == null || endNum == null || toothNum == null) {
      return false;
    }

    final min = startNum < endNum ? startNum : endNum;
    final max = startNum > endNum ? startNum : endNum;
    return toothNum >= min && toothNum <= max;
  }

  Color _resolveColor(Treatment treatment) {
    final fromConfig = _parseHex(treatment.colorHex);
    if (fromConfig != null) return fromConfig;

    final value = treatment.name.toLowerCase();
    if (value.contains('implante')) return const Color(0xFF0E7C7B);
    if (value.contains('corona')) return const Color(0xFF3A86FF);
    if (value.contains('limpieza')) return const Color(0xFF2A9D8F);
    if (value.contains('endodoncia')) return const Color(0xFF8338EC);
    if (value.contains('extracción') || value.contains('extraccion')) return const Color(0xFFD90429);
    if (value.contains('caries') || value.contains('obturación') || value.contains('obturacion')) {
      return const Color(0xFF111111);
    }
    return const Color(0xFF6C757D);
  }

  IconData _resolveIcon(Treatment treatment) {
    switch (treatment.iconKey) {
      case 'caries':
        return Icons.circle;
      case 'extraction':
        return Icons.content_cut;
      case 'implant':
        return Icons.hardware;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'crown':
        return Icons.workspace_premium;
      case 'root':
        return Icons.account_tree;
      case 'whitening':
        return Icons.brightness_5;
      case 'restoration':
        return Icons.build_circle;
      case 'prosthesis':
        return Icons.medical_services;
      case 'ortho':
        return Icons.straighten;
      case 'guard':
        return Icons.shield;
      case 'xray':
        return Icons.science;
      case 'periodontics':
        return Icons.grass;
      case 'bridge':
        return Icons.view_week;
      case 'veneer':
        return Icons.auto_awesome;
      case 'retainer':
        return Icons.align_horizontal_center;
      case 'occlusion':
        return Icons.adjust;
      case 'consult':
        return Icons.medical_information;
      case 'emergency':
        return Icons.emergency;
      case 'hygiene':
        return Icons.sanitizer;
      case 'diagnosis':
        return Icons.biotech;
      case 'sealant':
        return Icons.water_drop;
      case 'esthetic':
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'maintenance':
        return Icons.event_available;
      case 'sedation':
        return Icons.airline_seat_flat;
      case 'sensitivity':
        return Icons.bolt;
      case 'prosthesis_fixed':
        return Icons.view_week;
      case 'prosthesis_removable':
        return Icons.accessibility_new;
      case 'sutures':
        return Icons.linear_scale;
      case 'planning':
        return Icons.edit_calendar;
      case 'payment':
        return Icons.payments;
      case 'lab':
        return Icons.science_outlined;
      case 'followup':
        return Icons.assignment_turned_in;
      default:
        final value = treatment.name.toLowerCase();
        if (value.contains('caries') || value.contains('obturación') || value.contains('obturacion')) {
          return Icons.circle;
        }
        if (value.contains('extracción') || value.contains('extraccion')) {
          return Icons.content_cut;
        }
        if (value.contains('limpieza')) {
          return Icons.cleaning_services;
        }
        if (value.contains('implante')) {
          return Icons.hardware;
        }
        if (value.contains('corona')) {
          return Icons.workspace_premium;
        }
        if (value.contains('endodoncia')) {
          return Icons.account_tree;
        }
        return Icons.hexagon;
    }
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
