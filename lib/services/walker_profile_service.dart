import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walker_profile_model.dart';

class WalkerProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener perfil de un paseador específico
  Future<WalkerProfileModel?> getProfile(String userId) async {
    try {
      final doc = await _firestore.collection('walker_profiles').doc(userId).get();
      if (doc.exists) {
        // CORRECCIÓN: Pasar doc.id como segundo argumento
        return WalkerProfileModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error al obtener perfil: $e');
      return null;
    }
  }

  // Guardar/Actualizar perfil
  Future<bool> saveProfile(WalkerProfileModel profile) async {
    try {
      print('📤 INICIANDO GUARDADO DE PERFIL...');
      print('   userId: ${profile.userId}');
      print('   name: ${profile.name}');
      print('   bio: ${profile.bio}');
      print('   pricePerWalk: ${profile.pricePerWalk} (tipo: ${profile.pricePerWalk.runtimeType})');
      print('   latitude: ${profile.latitude}');
      print('   longitude: ${profile.longitude}');

      final data = profile.toMap();
      print('   Datos a enviar: $data');

      final docRef = _firestore.collection('walker_profiles').doc(profile.userId);
      print('   Referencia del documento: ${docRef.path}');

      await docRef.set(data, SetOptions(merge: true));

      print('✅ ¡GUARDADO EXITOSO EN FIREBASE!');
      return true;
    } catch (e, stackTrace) {
      print('❌ ERROR AL GUARDAR: $e');
      print('   Stack trace: $stackTrace');
      return false;
    }
  }

  // Obtener todos los paseadores verificados y disponibles (para dueños)
  Stream<List<WalkerProfileModel>> getAvailableWalkers() {
    return _firestore
        .collection('walker_profiles')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      // CORRECCIÓN: Pasar doc.id como segundo argumento aquí también
      return WalkerProfileModel.fromMap(doc.data(), doc.id);
    }).toList());
  }
}