import 'package:cloud_firestore/cloud_firestore.dart';

class WalkerProfileModel {
  final String userId;
  final String? name;
  final String bio;
  final double pricePerWalk;
  final String experience;
  final bool isAvailable;
  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final DateTime createdAt;

  WalkerProfileModel({
    required this.userId,
    this.name,
    required this.bio,
    required this.pricePerWalk,
    required this.experience,
    required this.isAvailable,
    this.latitude,
    this.longitude,
    required this.radiusKm,
    // CORRECCIÓN: Valor por defecto para evitar error al crear nuevo perfil
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'bio': bio,
      'pricePerWalk': pricePerWalk,
      'experience': experience,
      'isAvailable': isAvailable,
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WalkerProfileModel.fromMap(Map<String, dynamic> map, String docId) {
    return WalkerProfileModel(
      userId: map['userId'] ?? docId,
      name: map['name'],
      bio: map['bio'] ?? '',
      pricePerWalk: (map['pricePerWalk'] ?? 0.0).toDouble(),
      experience: map['experience'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      radiusKm: (map['radiusKm'] ?? 1.0).toDouble(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}