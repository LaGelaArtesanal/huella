import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // ✅ AGREGADO PARA APP CHECK
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

// ✅ 1. IMPORTAR LAS OPCIONES DE FIREBASE
import 'firebase_options.dart';

// Servicios
import 'services/settings_service.dart';

// Pantallas de Usuario
import 'screens/login_screen.dart';
import 'screens/home_owner_screen.dart';
import 'screens/walker_dashboard_screen.dart';
import 'screens/my_walks_screen.dart';
import 'screens/call_screen.dart';

// Pantallas de Administración
import 'admin/admin_login_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final AudioPlayer _globalRingtonePlayer = AudioPlayer();

// ==========================================
// 1. Manejador en Segundo Plano
// ==========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (message.data['type'] == 'incoming_call') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_call_data', json.encode(message.data));
    await _showLocalNotification(
      message.notification?.title ?? 'Llamada entrante',
      message.notification?.body ?? 'Tienes una llamada',
      message.data,
    );
  }
}

Future<void> _showLocalNotification(String? title, String? body, Map<String, dynamic> data) async {
  final androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'incoming_call_channel',
    'Llamadas Entrantes',
    channelDescription: 'Canal para llamadas entrantes',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.call,
    visibility: NotificationVisibility.public,
    fullScreenIntent: true,
  );

  await flutterLocalNotificationsPlugin.show(
    data['callId'].hashCode,
    title ?? 'Huella',
    body ?? 'Llamada entrante',
    NotificationDetails(android: androidPlatformChannelSpecifics),
    payload: json.encode(data),
  );
}

// ==========================================
// 2. Función Global para abrir llamada pendiente
// ==========================================
Future<void> _checkAndOpenPendingCall() async {
  print('🔍 Verificando llamada pendiente...');
  final prefs = await SharedPreferences.getInstance();
  final callDataStr = prefs.getString('pending_call_data');

  if (callDataStr == null || callDataStr.isEmpty) {
    print('❌ No hay datos en SharedPreferences');
    return;
  }

  try {
    final Map<String, dynamic> callData = json.decode(callDataStr);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      print('⚠️ Usuario no autenticado aún. Reintentando en 2s...');
      Future.delayed(const Duration(seconds: 2), _checkAndOpenPendingCall);
      return;
    }

    await prefs.remove('pending_call_data');

    if (currentUserId != callData['callerId']) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final isWalker = userDoc.data()?['role'] == 'walker';

      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: callData['callId'],
              walkId: callData['walkId'],
              isCaller: false,
              otherUserName: callData['callerName'] ?? 'Llamada',
              otherUserId: callData['callerId'],
              currentUserId: currentUserId,
              isVideoCall: callData['isVideo'] == true,
              isWalker: isWalker,
            ),
          ),
        );
        print('🚀 CallScreen empujada al navegador exitosamente');
      }
    }
  } catch (e) {
    print('❌ Error al procesar llamada pendiente: $e');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_call_data');
  }
}

// ==========================================
// 3. Widget Global para Escuchar Llamadas (Foreground)
// ==========================================
class GlobalCallListener extends StatefulWidget {
  final Widget child;
  const GlobalCallListener({super.key, required this.child});

  @override
  State<GlobalCallListener> createState() => _GlobalCallListenerState();
}

class _GlobalCallListenerState extends State<GlobalCallListener> {
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    _startGlobalListener();
  }

  void _startGlobalListener() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _callSubscription?.cancel();
      if (user != null) {
        _callSubscription = FirebaseFirestore.instance
            .collection('calls')
            .where('receiverId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'ringing')
            .snapshots()
            .listen((snapshot) async {
          if (snapshot.docs.isNotEmpty && mounted) {
            final callData = snapshot.docs.first.data();
            final callId = callData['callId'];
            final callerName = callData['callerName'] ?? 'Llamada entrante';
            final callerId = callData['callerId'];
            final walkId = callData['walkId'];
            final isVideo = callData['isVideo'] == true;

            bool isWalker = false;
            try {
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
              isWalker = userDoc.data()?['role'] == 'walker';
            } catch (e) {}

            try {
              if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(pattern: [0, 1000, 1000, 1000]);
              await _globalRingtonePlayer.setReleaseMode(ReleaseMode.loop);
              await _globalRingtonePlayer.setSource(AssetSource('sounds/ringtone.mp3'));
              await _globalRingtonePlayer.resume();
            } catch (e) {}

            if (mounted && navigatorKey.currentState != null) {
              navigatorKey.currentState!.push(
                MaterialPageRoute(
                  builder: (_) => PopScope(
                    canPop: false,
                    child: _IncomingCallDialog(
                      callId: callId,
                      walkId: walkId,
                      callerName: callerName,
                      callerId: callerId,
                      isVideo: isVideo,
                      currentUserId: user.uid,
                      isWalker: isWalker,
                      onStopRingtone: () {
                        _globalRingtonePlayer.stop();
                        Vibration.cancel();
                      },
                    ),
                  ),
                ),
              );
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ==========================================
// 4. Diálogo de Llamada Entrante
// ==========================================
class _IncomingCallDialog extends StatelessWidget {
  final String callId, walkId, callerName, callerId;
  final bool isVideo, isWalker;
  final String currentUserId;
  final VoidCallback onStopRingtone;

  const _IncomingCallDialog({
    required this.callId,
    required this.walkId,
    required this.callerName,
    required this.callerId,
    required this.isVideo,
    required this.currentUserId,
    required this.isWalker,
    required this.onStopRingtone
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: Center(
        child: AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
              children: [
                Icon(isVideo ? Icons.videocam : Icons.call, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Text('📞 $callerName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
              ]
          ),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 50, backgroundColor: Colors.blue.shade900, child: Icon(isVideo ? Icons.videocam : Icons.call, size: 50, color: Colors.blue.shade300)),
                const SizedBox(height: 16),
                Text(isVideo ? 'Videollamada entrante' : 'Llamada de audio entrante', style: const TextStyle(color: Colors.white70, fontSize: 16))
              ]
          ),
          actions: [
            TextButton(
                onPressed: () async {
                  onStopRingtone();
                  Navigator.pop(context);
                  await FirebaseFirestore.instance.collection('calls').doc(callId).update({'status': 'rejected'});
                },
                style: TextButton.styleFrom(backgroundColor: Colors.red.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('Rechazar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)))
            ),
            ElevatedButton(
                onPressed: () async {
                  onStopRingtone();
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, walkId: walkId, isCaller: false, otherUserName: callerName, otherUserId: callerId, currentUserId: currentUserId, isVideoCall: isVideo, isWalker: isWalker)));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                child: const Text('Contestar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. AuthWrapper (Enrutador Principal)
// ==========================================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
                final role = roleSnapshot.data!['role'];

                if (role == 'walker') {
                  return WalkerDashboardScreen(walkerId: user.uid);
                } else {
                  return HomeOwnerScreen(userId: user.uid, userName: user.displayName ?? 'Dueño');
                }
              }
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
            },
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
      },
    );
  }
}

// ==========================================
// 6. Función Principal
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ CONFIGURACIÓN DE STRIPE (MODO PRUEBAS)
  try {
    Stripe.publishableKey = 'pk_test_51UAHSHHweWHZEXEPBg0ffbep5vbCEwIk903hlahhUBAwRFPzr2qvAJ8KThLEnd8HNuqK8LNQpOS9CqI4OQJS3so70076e0wHpr';
    Stripe.merchantIdentifier = 'merchant.com.huella.app';
    Stripe.urlScheme = 'huella';
    await Stripe.instance.applySettings();
  } catch (e) {
    print('⚠️ [MAIN] Error al inicializar Stripe (la app continúa): $e');
  }

  // ✅ 2. INICIALIZAR FIREBASE CON LAS OPCIONES DE LA PLATAFORMA ACTUAL
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      print('ℹ️ [MAIN] Firebase ya estaba inicializado, se reutiliza la instancia.');
    } else {
      rethrow;
    }
  }

  // ✅ 3. INICIALIZAR APP CHECK CON MODO DEPURACIÓN (Usa el token del AndroidManifest)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  await initializeDateFormatting('es_ES', null);
  await SettingsService.loadSettings();

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false, criticalAlert: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null && initialMessage.data['type'] == 'incoming_call') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_call_data', json.encode(initialMessage.data));
  }

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null && response.payload!.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_call_data', response.payload!);
        await _checkAndOpenPendingCall();
      }
    },
  );

  final androidImplementation = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImplementation?.createNotificationChannel(const AndroidNotificationChannel(
      'incoming_call_channel',
      'Llamadas Entrantes',
      description: 'Canal para llamadas',
      importance: Importance.max,
      playSound: true,
      enableVibration: true
  ));

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    if (message.data['type'] == 'incoming_call') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_call_data', json.encode(message.data));
      await _checkAndOpenPendingCall();
    }
  });

  runApp(const MyApp());
}

// ==========================================
// 7. Widget Principal
// ==========================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalCallListener(
      child: MaterialApp(
        title: 'Huella',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: true),
        home: const AuthWrapper(),
        routes: {
          '/admin': (context) => const AdminLoginScreen(),
        },
      ),
    );
  }
}