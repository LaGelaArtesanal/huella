import 'package:cloud_firestore/cloud_firestore.dart';

class WalkModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final String petId;
  final String petName;
  final String status;
  final int durationMinutes;
  final double priceMultiplier;
  final double amount;
  final bool isImmediate;
  final DateTime scheduledTime;
  final DateTime createdAt;

  // Campos opcionales para ubicación y asignación
  final double? ownerLat;
  final double? ownerLng;
  final String? walkerId;

  WalkModel({
    required this.id,
    this.ownerId = '',
    this.ownerName = '',
    this.petId = '',
    this.petName = '',
    this.status = 'pending',
    this.durationMinutes = 50,
    this.priceMultiplier = 1.0,
    this.amount = 0.0,
    this.isImmediate = false,
    DateTime? scheduledTime,
    DateTime? createdAt,
    this.ownerLat,
    this.ownerLng,
    this.walkerId,
  }) : scheduledTime = scheduledTime ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  // Función auxiliar segura para convertir datos de Firestore a DateTime
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  factory WalkModel.fromMap(Map<String, dynamic> map, String documentId) {
    return WalkModel(
      id: documentId,
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      petId: map['petId'] ?? '',
      petName: map['petName'] ?? '',
      status: map['status'] ?? 'pending',
      durationMinutes: (map['durationMinutes'] ?? 50).toInt(),
      priceMultiplier: (map['priceMultiplier'] ?? 1.0).toDouble(),
      amount: (map['amount'] ?? 0.0).toDouble(),
      isImmediate: map['isImmediate'] ?? false,

      // CAMBIO CLAVE: Usar la función segura en lugar del cast directo
      scheduledTime: _parseDate(map['scheduledTime']),
      createdAt: _parseDate(map['createdAt']),

      ownerLat: map['ownerLat']?.toDouble(),
      ownerLng: map['ownerLng']?.toDouble(),
      walkerId: map['walkerId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'petId': petId,
      'petName': petName,
      'status': status,
      'durationMinutes': durationMinutes,
      'priceMultiplier': priceMultiplier,
      'amount': amount,
      'isImmediate': isImmediate,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'createdAt': Timestamp.fromDate(createdAt),
      'ownerLat': ownerLat,
      'ownerLng': ownerLng,
      'walkerId': walkerId,
    };
  }

  static Future<void> updateStatus(String walkId, String newStatus) async {
    await FirebaseFirestore.instance.collection('walks').doc(walkId).update({
      'status': newStatus,
    });
  }
}