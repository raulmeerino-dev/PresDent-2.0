class Treatment {
  final int? id;
  final String name;
  final double price;
  final String? colorHex;
  final String? iconKey;
  final String? pieceType;

  const Treatment({
    this.id,
    required this.name,
    required this.price,
    this.colorHex,
    this.iconKey,
    this.pieceType,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': name,
      'precio': price,
      'color_hex': colorHex,
      'icono': iconKey,
      'pieza_tipo': pieceType,
    };
  }

  factory Treatment.fromMap(Map<String, Object?> map) {
    return Treatment(
      id: map['id'] as int?,
      name: map['nombre'] as String,
      price: (map['precio'] as num).toDouble(),
      colorHex: map['color_hex'] as String?,
      iconKey: map['icono'] as String?,
      pieceType: map['pieza_tipo'] as String?,
    );
  }
}
