import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'owner', 'walker', 'admin', 'temp_admin'
  final DateTime createdAt;

  // Campos nuevos para Admin/Seguridad
  final bool isVerified;      // ¿Documentos aprobados?
  final bool isBlocked;       // ¿Bloqueado por mala conducta?
  final List<String> documentUrls; // URLs de INE, antecedentes, etc.
  final String? selfieUrl;    // URL de la foto selfie (separada para UI)
  final String? adminToken;   // Token usado para registro temporal

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.isVerified = false,
    this.isBlocked = false,
    this.documentUrls = const [],
    this.selfieUrl,
    this.adminToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt), // ✅ MEJORA: Usar Timestamp nativo
      'isVerified': isVerified,
      'isBlocked': isBlocked,
      'documentUrls': documentUrls,
      'selfieUrl': selfieUrl,
      'adminToken': adminToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'owner',
      // ✅ Manejo seguro de Timestamp o String (por compatibilidad)
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      isVerified: map['isVerified'] ?? false,
      isBlocked: map['isBlocked'] ?? false,
      documentUrls: List<String>.from(map['documentUrls'] ?? []),
      selfieUrl: map['selfieUrl'],
      adminToken: map['adminToken'],
    );
  }
}