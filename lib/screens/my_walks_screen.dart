import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/walk_model.dart';
import 'chat_screen.dart';
import 'call_screen.dart';

class MyWalksScreen extends StatefulWidget {
  final String walkerId;
  const MyWalksScreen({super.key, required this.walkerId});

  @override
  State<MyWalksScreen> createState() => _MyWalksScreenState();
}

class _MyWalksScreenState extends State<MyWalksScreen> {
  Timer? _alarmTimer;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _gpsStatusStream; // ✅ NUEVO: Listener del estado del GPS
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isSharingLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startAlarmChecker();
    _checkAndForceGPS(); // ✅ Iniciamos verificando el GPS
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    _positionStream?.cancel();
    _gpsStatusStream?.cancel(); // ✅ Limpiamos el listener
    super.dispose();
  }

  // ✅ NUEVO: Verifica y OBLIGA a tener el GPS encendido
  Future<void> _checkAndForceGPS() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showGpsRequiredDialog('Se requieren permisos de ubicación para continuar.');
        return;
      }
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showGpsRequiredDialog('El GPS está apagado. Es obligatorio activarlo para realizar el paseo.');
    } else {
      _startLocationSharing();
      _listenToGpsChanges(); // ✅ Escuchar si lo apagan después
    }
  }

  // ✅ NUEVO: Diálogo que no se puede cerrar hasta activar el GPS
  void _showGpsRequiredDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // No se puede cerrar con el botón "Atrás"
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('📍 GPS Requerido'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                await Geolocator.openLocationSettings();
                // Verificar si lo activó al regresar
                final enabled = await Geolocator.isLocationServiceEnabled();
                if (enabled && mounted) {
                  Navigator.pop(context);
                  _startLocationSharing();
                  _listenToGpsChanges();
                } else if (mounted) {
                  Navigator.pop(context);
                  _showGpsRequiredDialog('El GPS sigue apagado. No puedes continuar sin él.');
                }
              },
              child: const Text('Activar GPS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Detecta en tiempo real si el usuario apaga el GPS
  void _listenToGpsChanges() {
    _gpsStatusStream = Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.disabled && _isSharingLocation) {
        setState(() => _isSharingLocation = false);
        _positionStream?.cancel();
        _showGpsRequiredDialog('⚠️ Detectamos que apagaste el GPS. Por favor, vuelvelo a activar.');
      } else if (status == ServiceStatus.enabled && !_isSharingLocation) {
        _startLocationSharing();
      }
    });
  }

  Future<void> _startLocationSharing() async {
    if (_isSharingLocation) return; // Evitar múltiples streams

    setState(() => _isSharingLocation = true);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // ✅ Máxima precisión para mapas en tiempo real
        distanceFilter: 10, // Actualiza cada 10 metros
      ),
    ).listen((Position position) async {
      // Actualizamos TODOS los paseos activos de este paseador
      final snapshot = await FirebaseFirestore.instance
          .collection('walks')
          .where('walkerId', isEqualTo: widget.walkerId)
          .where('status', whereIn: ['accepted', 'in_progress'])
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'walkerLat': position.latitude,
          'walkerLng': position.longitude,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(initSettings);
  }

  void _startAlarmChecker() {
    _alarmTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final now = DateTime.now();
      final snapshot = await FirebaseFirestore.instance
          .collection('walks')
          .where('walkerId', isEqualTo: widget.walkerId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final scheduledTime = (data['scheduledTime'] as Timestamp).toDate();
        final alarmTime = scheduledTime.subtract(const Duration(minutes: 5)); // 5 min antes

        if (now.isAfter(alarmTime) && data['alarmNotified'] != true) {
          const androidDetails = AndroidNotificationDetails(
            'walk_alarm_channel',
            'Alarma de Paseo',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
          );
          const notificationDetails = NotificationDetails(android: androidDetails);

          await _notificationsPlugin.show(
            doc.id.hashCode,
            '⏰ ¡Faltan 5 minutos!',
            'Prepárate para iniciar el paseo',
            notificationDetails,
            payload: 'walk_alarm',
          );

          await FirebaseFirestore.instance.collection('walks').doc(doc.id).update({'alarmNotified': true});
        }
      }
    });
  }

  String _getChatId(String id1, String id2) {
    List<String> ids = [id1, id2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _completeWalk(String walkId) async {
    // ✅ Detener el rastreo al finalizar
    _positionStream?.cancel();
    setState(() => _isSharingLocation = false);

    await FirebaseFirestore.instance.collection('walks').doc(walkId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _notifyArrival(String walkId) async {
    await FirebaseFirestore.instance.collection('walks').doc(walkId).update({
      'status': 'in_progress', // ✅ Cambiamos a en progreso al llegar
      'walkerArrived': true,
      'arrivedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔔 Notificación de llegada enviada al dueño'), backgroundColor: Colors.purple),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myWalksStream = FirebaseFirestore.instance
        .collection('walks')
        .where('walkerId', isEqualTo: widget.walkerId)
        .where('status', whereIn: ['accepted', 'in_progress']) // ✅ Solo mostramos activos
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('Mis Paseos Activos', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(
                  Icons.my_location,
                  color: _isSharingLocation ? Colors.white : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _isSharingLocation ? 'GPS ON' : 'GPS OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isSharingLocation ? Colors.white : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: myWalksStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            ));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No tienes paseos activos', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Acepta una solicitud para verla aquí', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            );
          }

          final walks = snapshot.data!.docs
              .map((doc) => WalkModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          walks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: walks.length,
            itemBuilder: (context, index) {
              final walk = walks[index];

              return FutureBuilder<List<DocumentSnapshot>>(
                future: Future.wait([
                  FirebaseFirestore.instance.collection('pets').doc(walk.petId).get(),
                  FirebaseFirestore.instance.collection('users').doc(walk.ownerId).get(),
                ]),
                builder: (context, detailsSnapshot) {
                  String petName = 'Mascota';
                  String ownerName = 'Dueño';
                  String address = '';
                  String reference = '';

                  if (detailsSnapshot.hasData) {
                    final petData = detailsSnapshot.data![0].data() as Map<String, dynamic>?;
                    final ownerData = detailsSnapshot.data![1].data() as Map<String, dynamic>?;

                    if (petData != null) petName = petData['name'] ?? 'Mascota';
                    if (ownerData != null) {
                      ownerName = ownerData['name'] ?? 'Dueño';
                      address = ownerData['address'] ?? '';
                      reference = ownerData['locationReference'] ?? '';
                    }
                  }

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(backgroundColor: Colors.green.shade100, child: Icon(Icons.check_circle, color: Colors.green.shade700)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ownerName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('🐶 $petName', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: walk.status == 'in_progress' ? Colors.green.shade100 : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12)
                                ),
                                child: Text(
                                  walk.status == 'in_progress' ? 'EN PROGRESO' : 'CONFIRMADO',
                                  style: TextStyle(
                                      color: walk.status == 'in_progress' ? Colors.green.shade800 : Colors.blue.shade800,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade700), const SizedBox(width: 8), Text('${walk.scheduledTime.day}/${walk.scheduledTime.month}/${walk.scheduledTime.year}', style: const TextStyle(fontWeight: FontWeight.w500))]),
                                const SizedBox(height: 8),
                                Row(children: [Icon(Icons.access_time, size: 16, color: Colors.blue.shade700), const SizedBox(width: 8), Text('${walk.scheduledTime.hour}:${walk.scheduledTime.minute.toString().padLeft(2, '0')} hrs', style: const TextStyle(fontWeight: FontWeight.w500))]),
                                if (address.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(address, style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500)))
                                  ]),
                                ],
                                if (reference.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Padding(
                                      padding: const EdgeInsets.only(left: 24),
                                      child: Text('📝 Ref: $reference', style: TextStyle(fontSize: 12, color: Colors.orange.shade600, fontStyle: FontStyle.italic))
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botón de Llegada (solo si está 'accepted')
                          if (walk.status == 'accepted') ...[
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.icon(
                                onPressed: () => _notifyArrival(walk.id),
                                icon: const Icon(Icons.notifications_active, size: 18),
                                label: Text('Llegué al domicilio', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final chatId = _getChatId(walk.ownerId, widget.walkerId);
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                                      chatId: chatId,
                                      currentUserId: widget.walkerId,
                                      otherUserId: walk.ownerId,
                                      isWalker: true,
                                    )));
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                  label: Text('Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ownerDoc = await FirebaseFirestore.instance.collection('users').doc(walk.ownerId).get();
                                    final ownerName = ownerDoc.data()?['name'] ?? 'Dueño';
                                    if (!context.mounted) return;
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
                                      callId: walk.id,
                                      isCaller: true,
                                      otherUserName: ownerName,
                                      currentUserId: widget.walkerId,
                                    )));
                                  },
                                  icon: const Icon(Icons.phone, size: 16),
                                  label: Text('Llamar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: ElevatedButton.icon(
                                  onPressed: () => _completeWalk(walk.id),
                                  icon: const Icon(Icons.done_all, size: 16),
                                  label: Text('Fin', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}