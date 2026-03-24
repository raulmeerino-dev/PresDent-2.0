class Doctor {
  final int? id;
  final String name;
  final bool isAdmin;
  final String? colorHex;

  const Doctor({
    this.id,
    required this.name,
    this.isAdmin = false,
    this.colorHex,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': name,
      'is_admin': isAdmin ? 1 : 0,
      'color_hex': colorHex,
    };
  }

  factory Doctor.fromMap(Map<String, Object?> map) {
    return Doctor(
      id: map['id'] as int?,
      name: map['nombre'] as String,
      isAdmin: (map['is_admin'] as int? ?? 0) == 1,
      colorHex: map['color_hex'] as String?,
    );
  }
}
