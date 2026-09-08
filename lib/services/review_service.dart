import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Envía una reseña, marca el paseo como calificado y actualiza el promedio del perfil
  Future<void> submitReview({
    required String walkId,
    required String reviewerId,
    required String reviewedId,
    required String reviewedCollection,
    required int rating,
    required String comment,
    required double tipAmount,
  }) async {
    try {
      print('📤 [ReviewService] Iniciando envío de reseña...');
      print('📤 [ReviewService] walkId: $walkId');
      print(' [ReviewService] reviewerId: $reviewerId');
      print('📤 [ReviewService] reviewedId: $reviewedId');
      print('📤 [ReviewService] rating: $rating');
      print('📤 [ReviewService] tipAmount: $tipAmount');

      // 1. Guardar el documento de la reseña
      print('📝 [ReviewService] Paso 1: Guardando reseña en colección reviews...');
      await _firestore.collection('reviews').add({
        'walkId': walkId,
        'reviewerId': reviewerId,
        'reviewedId': reviewedId,
        'rating': rating,
        'comment': comment,
        'tipAmount': tipAmount,
        'tipStatus': tipAmount > 0 ? 'pending' : 'none',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ [ReviewService] Reseña guardada exitosamente');

      // 2. Marcar el paseo como calificado
      print('📝 [ReviewService] Paso 2: Marcando paseo como calificado...');
      await _firestore.collection('walks').doc(walkId).update({
        'isRated': true,
      });
      print('✅ [ReviewService] Paseo marcado como calificado');

      // 3. Actualizar el promedio en el perfil del usuario calificado
      print('📝 [ReviewService] Paso 3: Actualizando promedio del perfil...');
      final profileRef = _firestore.collection(reviewedCollection).doc(reviewedId);
      final profileDoc = await profileRef.get();

      if (profileDoc.exists) {
        final data = profileDoc.data()!;
        final double currentAvg = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        final int totalReviews = data['totalReviews'] ?? 0;

        final double newAvg = ((currentAvg * totalReviews) + rating) / (totalReviews + 1);

        await profileRef.update({
          'averageRating': newAvg,
          'totalReviews': totalReviews + 1,
        });

        print('✅ [ReviewService] Promedio actualizado a $newAvg');
      } else {
        print('⚠️ [ReviewService] El perfil no existe, saltando actualización de promedio');
      }

      print('🎉 [ReviewService] ¡Reseña completada exitosamente!');

    } catch (e, stackTrace) {
      print('❌ [ReviewService] ERROR: $e');
      print('❌ [ReviewService] StackTrace: $stackTrace');
      rethrow; // Relanzar para que la UI muestre el error
    }
  }

  /// Obtener las reseñas de un usuario específico
  Stream<List<Map<String, dynamic>>> getUserReviews(String userId) {
    return _firestore
        .collection('reviews')
        .where('reviewedId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}