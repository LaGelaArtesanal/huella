import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize(String userId) async {
    // 1. Inicializar notificaciones locales (seguro llamarlo varias veces)
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 Notificación local tocada: ${response.payload}');
        // Aquí podrías agregar lógica de navegación global si lo necesitas
      },
    );

    // 2. Solicitar permisos explícitamente (buena práctica)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('📱 Permisos de notificación: ${settings.authorizationStatus}');

    // 3. Obtener y guardar token
    String? token = await _messaging.getToken();
    print('🔔 Token FCM: $token');
    if (token != null) {
      await _saveToken(userId, token);
    }

    // 4. Escuchar renovación de token (Firebase lo hace a veces)
    _messaging.onTokenRefresh.listen((newToken) {
      print('🔔 Token renovado: $newToken');
      _saveToken(userId, newToken);
    });

    // 5. Manejar mensajes en PRIMER PLANO (cuando la app está abierta)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Mensaje en primer plano: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 6. Manejar cuando el usuario TOCA la notificación (desde background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Notificación abierta: ${message.data}');
      _handleNotificationTap(message.data);
    });
  }

  Future<void> _saveToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmToken': token,
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
    }).catchError((e) {
      print('⚠️ Error guardando token: $e');
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    // ✅ Determinar el canal basado en el tipo de mensaje para que suene correctamente
    final isChat = message.data['type'] == 'chat';
    final channelId = isChat ? 'chat_message_channel' : 'high_importance_channel';
    final channelName = isChat ? 'Mensajes de Chat Huella' : 'Notificaciones Importantes Huella';

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notificaciones de la app Huella',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,       // ✅ Fuerza el sonido
      enableVibration: true, // ✅ Fuerza la vibración
    );

    final NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // ✅ ID único para no sobrescribir
      message.notification?.title ?? 'Huella',
      message.notification?.body ?? 'Nueva notificación',
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    if (data['type'] == 'chat') {
      print('👉 Navegar al chat: ${data['chatId']}');
      // Aquí iría la lógica de navegación global si la tienes configurada
    } else if (data['type'] == 'new_walk') {
      print('👉 Navegar a solicitudes disponibles');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}