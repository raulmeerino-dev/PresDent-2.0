import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/estimate.dart';

class PdfService {
  PdfService._();

  static final PdfService instance = PdfService._();
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

  Future<File> buildEstimatePdf({
    required String patientName,
    required DateTime date,
    required List<EstimateDetailView> details,
    String clinicName = 'Clínica Dental Huberto Merino',
    Uint8List? clinicLogoBytes,
    String? additionalComments,
  }) async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      ),
    );
    final formatter = NumberFormat.decimalPattern('es_ES');

    final total = details.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final byTooth = <String, List<EstimateDetailView>>{};
    final byAssignment = <String, List<EstimateDetailView>>{};
    for (final item in details.where((d) => d.toothCode != null && d.toothCode!.trim().isNotEmpty)) {
      final assignment = item.toothCode!.trim().toUpperCase();
      byAssignment.putIfAbsent(assignment, () => []).add(item);
      for (final tooth in _expandAssignmentToTeeth(assignment)) {
        byTooth.putIfAbsent(tooth, () => []).add(item);
      }
    }

    final logoImage = clinicLogoBytes != null ? pw.MemoryImage(clinicLogoBytes) : null;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        clinicName,
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
                  if (logoImage != null)
                    pw.SizedBox(
                      width: 190,
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: _buildHeaderLogo(logoImage),
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text('Presupuesto de tratamiento dental', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 18),
              pw.Text('Paciente: $patientName'),
              pw.Text('Fecha: ${DateFormat('dd/MM/yyyy').format(date)}'),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: const ['Tratamiento', 'Pieza', 'Cantidad', 'P. unitario', 'Total'],
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                cellAlignment: pw.Alignment.centerLeft,
                data: details
                    .map(
                      (item) => [
                        item.treatmentName,
                        _formatToothLabel(item.toothCode),
                        item.quantity.toString(),
                        _formatEuro(item.unitPrice, formatter),
                        _formatEuro(item.lineTotal, formatter),
                      ],
                    )
                    .toList(),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'Odontograma (resumen por pieza)',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              _buildOdontogramVisual(byTooth),
              pw.SizedBox(height: 8),
              if (byTooth.isEmpty)
                pw.Text('No hay piezas dentales asignadas en este presupuesto.')
              else
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: byAssignment.entries
                      .map(
                        (entry) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 3),
                          child: pw.Text(
                            '${_formatToothLabel(entry.key)}: ${entry.value.map((d) => '${d.treatmentName} x${d.quantity}').join(', ')}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total final: ${_formatEuro(total, formatter)}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (additionalComments != null && additionalComments.trim().isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.blueGrey100),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Comentarios adicionales',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(additionalComments.trim(), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final fileName = 'presupuesto_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.Widget _buildHeaderLogo(pw.MemoryImage logoImage) {
    return pw.Container(
      width: 180,
      height: 70,
      alignment: pw.Alignment.centerRight,
      child: pw.Image(
        logoImage,
        fit: pw.BoxFit.contain,
        alignment: pw.Alignment.centerRight,
      ),
    );
  }

  String _formatEuro(double amount, NumberFormat formatter) {
    return '${formatter.format(amount)} \u20AC';
  }

  String _formatToothLabel(String? value) {
    final normalized = value?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return '-';
    if (normalized == 'X') return 'General (X)';
    if (normalized == '+') return 'Arcada superior (+)';
    if (normalized == '-') return 'Arcada inferior (-)';
    if (RegExp(r'^\d{2}-\d{2}$').hasMatch(normalized)) return 'Sector $normalized';
    return 'Pieza $normalized';
  }

  Iterable<String> _expandAssignmentToTeeth(String assignment) sync* {
    final raw = assignment.trim().toUpperCase();
    if (raw.isEmpty) return;

    if (RegExp(r'^\d{2}$').hasMatch(raw) && _allTeeth.contains(raw)) {
      yield raw;
      return;
    }

    if (raw == '+') {
      yield* _topRight;
      yield* _topLeft;
      return;
    }

    if (raw == '-') {
      yield* _bottomLeft;
      yield* _bottomRight;
      return;
    }

    final rangeMatch = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(raw);
    if (rangeMatch == null) return;

    final start = rangeMatch.group(1)!;
    final end = rangeMatch.group(2)!;
    if (!_allTeeth.contains(start) || !_allTeeth.contains(end)) return;

    final quadrant = start[0];
    if (end[0] != quadrant) return;

    final startNum = int.tryParse(start[1]);
    final endNum = int.tryParse(end[1]);
    if (startNum == null || endNum == null) return;

    final min = startNum < endNum ? startNum : endNum;
    final max = startNum > endNum ? startNum : endNum;
    for (var i = min; i <= max; i++) {
      final code = '$quadrant$i';
      if (_allTeeth.contains(code)) {
        yield code;
      }
    }
  }

  Future<void> sharePdf(File pdfFile) async {
    await Share.shareXFiles([XFile(pdfFile.path)], text: 'Presupuesto odontológico');
  }

  pw.Widget _buildOdontogramVisual(Map<String, List<EstimateDetailView>> byTooth) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildOdontogramRow(_topRight, _topLeft, byTooth),
        pw.SizedBox(height: 6),
        _buildOdontogramRow(_bottomLeft, _bottomRight, byTooth),
      ],
    );
  }

  pw.Widget _buildOdontogramRow(
    List<String> left,
    List<String> right,
    Map<String, List<EstimateDetailView>> byTooth,
  ) {
    return pw.Row(
      children: [
        ...left.map((tooth) => _buildToothCell(tooth, byTooth[tooth] ?? const [])),
        pw.SizedBox(width: 10),
        ...right.map((tooth) => _buildToothCell(tooth, byTooth[tooth] ?? const [])),
      ],
    );
  }

  pw.Widget _buildToothCell(String toothCode, List<EstimateDetailView> items) {
    final hasTreatments = items.isNotEmpty;
    final cellColor = hasTreatments ? PdfColors.teal300 : PdfColors.blueGrey50;
    final marks = items.length > 4 ? 4 : items.length;

    return pw.Container(
      width: 23,
      height: 28,
      margin: const pw.EdgeInsets.only(right: 2),
      decoration: pw.BoxDecoration(
        color: cellColor,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.blueGrey400),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            toothCode,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: hasTreatments ? PdfColors.white : PdfColors.blueGrey800,
            ),
          ),
          if (marks > 0)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: List.generate(
                marks,
                (_) => pw.Container(
                  width: 3,
                  height: 3,
                  margin: const pw.EdgeInsets.only(top: 1, right: 1),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool get canOpenFileLocationDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> openPdfLocation(File pdfFile) async {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,${pdfFile.path}']);
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', pdfFile.path]);
      return;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [pdfFile.parent.path]);
    }
  }
}
