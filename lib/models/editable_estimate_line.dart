import 'treatment.dart';

class EditableEstimateLine {
  Treatment treatment;
  int quantity;
  double unitPrice;
  String? note;
  String? toothCode;

  EditableEstimateLine({
    required this.treatment,
    required this.quantity,
    required this.unitPrice,
    this.note,
    this.toothCode,
  });

  double get lineTotal => quantity * unitPrice;
}
