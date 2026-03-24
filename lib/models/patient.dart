class Patient {
  final int? id;
  final String name;
  final String? phone;
  final String? notes;

  const Patient({
    this.id,
    required this.name,
    this.phone,
    this.notes,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': name,
      'telefono': phone,
      'notas': notes,
    };
  }

  factory Patient.fromMap(Map<String, Object?> map) {
    return Patient(
      id: map['id'] as int?,
      name: map['nombre'] as String,
      phone: map['telefono'] as String?,
      notes: map['notas'] as String?,
    );
  }
}
