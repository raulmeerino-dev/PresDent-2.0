class Doctor {
  final int? id;
  final String name;

  const Doctor({this.id, required this.name});

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': name,
    };
  }

  factory Doctor.fromMap(Map<String, Object?> map) {
    return Doctor(
      id: map['id'] as int?,
      name: map['nombre'] as String,
    );
  }
}
