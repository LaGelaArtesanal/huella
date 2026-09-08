import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize(String userId) async {
    try {
      // 1. Pedir permisos (si no los tiene)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Permisos de notificación concedidos');

        // 2. Obtener el token del dispositivo
        String? token = await _messaging.getToken();

        if (token != null) {
          print('📱 Token FCM obtenido: $token');

          // 3. ✅ GUARDAR EL TOKEN EN FIRESTORE (¡CRUCIAL!)
          await _firestore.collection('users').doc(userId).update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          print('✅ Token guardado en Firestore para el usuario: $userId');
        }
      } else {
        print('⚠️ Permisos de notificación denegados por el usuario');
      }

      // 4. Escuchar cambios de token (por si el dispositivo lo actualiza)
      _messaging.onTokenRefresh.listen((newToken) async {
        print('🔄 Token actualizado: $newToken');
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': newToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      });

    } catch (e) {
      print('❌ Error inicializando notificaciones: $e');
    }
  }
}