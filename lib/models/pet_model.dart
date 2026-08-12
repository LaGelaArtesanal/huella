class PetModel {
  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final String size; // 'small', 'medium', 'large', 'giant'
  final int age;
  final String? photoUrl;
  final DateTime createdAt;

  PetModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.breed,
    required this.size,
    required this.age,
    this.photoUrl,
    required this.createdAt,
  });

  // NUEVO: Método para obtener multiplicador de precio
  double getPriceMultiplier() {
    switch (size.toLowerCase()) {
      case 'small': return 1.0;
      case 'medium': return 1.3;
      case 'large': return 1.6;
      case 'giant': return 2.0;
      default: return 1.0;
    }
  }

  // NUEVO: Método para obtener etiqueta legible
  String getSizeLabel() {
    switch (size.toLowerCase()) {
      case 'small': return 'Pequeño (<10kg)';
      case 'medium': return 'Mediano (10-25kg)';
      case 'large': return 'Grande (25-45kg)';
      case 'giant': return 'Gigante (>45kg)';
      default: return 'Tamaño no especificado';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'breed': breed,
      'size': size,
      'age': age,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PetModel.fromMap(Map<String, dynamic> map, String docId) {
    return PetModel(
      id: docId,
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      breed: map['breed'] ?? '',
      size: map['size'] ?? 'medium',
      age: map['age'] ?? 0,
      photoUrl: map['photoUrl'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}