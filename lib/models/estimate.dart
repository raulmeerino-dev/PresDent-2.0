import 'treatment.dart';

class Estimate {
  final int? id;
  final int patientId;
  final DateTime date;
  final double total;

  const Estimate({
    this.id,
    required this.patientId,
    required this.date,
    required this.total,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'paciente_id': patientId,
      'fecha': date.toIso8601String(),
      'total': total,
    };
  }

  factory Estimate.fromMap(Map<String, Object?> map) {
    return Estimate(
      id: map['id'] as int?,
      patientId: map['paciente_id'] as int,
      date: DateTime.parse(map['fecha'] as String),
      total: (map['total'] as num).toDouble(),
    );
  }
}

class EstimateDetail {
  final int? id;
  final int estimateId;
  final int treatmentId;
  final int quantity;
  final double unitPrice;
  final String? toothCode;

  const EstimateDetail({
    this.id,
    required this.estimateId,
    required this.treatmentId,
    required this.quantity,
    required this.unitPrice,
    this.toothCode,
  });

  double get lineTotal => quantity * unitPrice;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'presupuesto_id': estimateId,
      'tratamiento_id': treatmentId,
      'cantidad': quantity,
      'precio_unitario': unitPrice,
      'pieza_dental': toothCode,
    };
  }

  factory EstimateDetail.fromMap(Map<String, Object?> map) {
    return EstimateDetail(
      id: map['id'] as int?,
      estimateId: map['presupuesto_id'] as int,
      treatmentId: map['tratamiento_id'] as int,
      quantity: map['cantidad'] as int,
      unitPrice: (map['precio_unitario'] as num).toDouble(),
      toothCode: map['pieza_dental'] as String?,
    );
  }
}

class EstimateSummary {
  final int id;
  final int patientId;
  final String patientName;
  final String? doctorName;
  final DateTime date;
  final double total;

  const EstimateSummary({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.doctorName,
    required this.date,
    required this.total,
  });

  factory EstimateSummary.fromMap(Map<String, Object?> map) {
    return EstimateSummary(
      id: map['id'] as int,
      patientId: map['paciente_id'] as int,
      patientName: map['paciente_nombre'] as String,
      doctorName: map['doctor_nombre'] as String?,
      date: DateTime.parse(map['fecha'] as String),
      total: (map['total'] as num).toDouble(),
    );
  }
}

class EstimateDetailView {
  final int detailId;
  final int treatmentId;
  final String treatmentName;
  final int quantity;
  final double unitPrice;
  final String? toothCode;

  const EstimateDetailView({
    required this.detailId,
    required this.treatmentId,
    required this.treatmentName,
    required this.quantity,
    required this.unitPrice,
    this.toothCode,
  });

  double get lineTotal => quantity * unitPrice;

  factory EstimateDetailView.fromMap(Map<String, Object?> map) {
    return EstimateDetailView(
      detailId: map['id'] as int,
      treatmentId: map['tratamiento_id'] as int,
      treatmentName: map['tratamiento_nombre'] as String,
      quantity: map['cantidad'] as int,
      unitPrice: (map['precio_unitario'] as num).toDouble(),
      toothCode: map['pieza_dental'] as String?,
    );
  }
}

class ParsedTreatment {
  final Treatment treatment;
  final int quantity;
  final String? note;

  const ParsedTreatment({
    required this.treatment,
    required this.quantity,
    this.note,
  });
}
