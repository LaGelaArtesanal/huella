import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener todos los usuarios (para tu dashboard)
  Stream<List<UserModel>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList()
    );
  }

  // Aprobar/Rechazar documentos de un paseador
  Future<void> updateVerification(String userId, bool isVerified) async {
    await _firestore.collection('users').doc(userId).update({
      'isVerified': isVerified,
    });
  }

  // Bloquear/Desbloquear usuario (dueño o paseador)
  Future<void> updateUserBlockStatus(String userId, bool isBlocked) async {
    await _firestore.collection('users').doc(userId).update({
      'isBlocked': isBlocked,
    });
  }

  // Generar token temporal para nuevo admin
  // En producción esto debería estar más seguro, pero para MVP funciona
  Future<String> generateAdminToken(String createdBy) async {
    final token = 'HU-ADMIN-${DateTime.now().millisecondsSinceEpoch}';
    await _firestore.collection('admin_tokens').doc(token).set({
      'token': token,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
    });
    return token;
  }

  // Validar token durante registro
  Future<bool> validateAdminToken(String token) async {
    final doc = await _firestore.collection('admin_tokens').doc(token).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    final isActive = data['isActive'] == true;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();

    return isActive && expiresAt.isAfter(DateTime.now());
  }

  // Desactivar token (cuando termine el contrato)
  Future<void> revokeAdminToken(String token) async {
    await _firestore.collection('admin_tokens').doc(token).update({
      'isActive': false,
    });
  }
}