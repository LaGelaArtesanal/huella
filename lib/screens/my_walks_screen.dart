import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/walk_model.dart';
import 'chat_screen.dart';
import 'call_screen.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';

// ==========================================
// WIDGET INDEPENDIENTE PARA EL CRONÓMETRO
// ==========================================
class CountdownTimerWidget extends StatefulWidget {
  final DateTime? startTime;
  final int durationMinutes;
  const CountdownTimerWidget({super.key, this.startTime, required this.durationMinutes});

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _remainingSeconds {
    if (widget.startTime == null) return 0;
    final endTime = widget.startTime!.add(Duration(minutes: widget.durationMinutes));
    final remaining = endTime.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  String get _formattedTime {
    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _remainingSeconds <= 300;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isUrgent ? Colors.red.shade300 : Colors.green.shade200, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 14, color: isUrgent ? Colors.red.shade700 : Colors.green.shade700),
          const SizedBox(height: 2),
          Text(
            _formattedTime,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: isUrgent ? Colors.red.shade700 : Colors.green.shade700),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA PRINCIPAL DE PASEOS ACTIVOS
// ==========================================
class MyWalksScreen extends StatefulWidget {
  final String walkerId;
  const MyWalksScreen({super.key, required this.walkerId});

  @override
  State<MyWalksScreen> createState() => _MyWalksScreenState();
}

class _MyWalksScreenState extends State<MyWalksScreen> {
  Timer? _alarmTimer;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _gpsStatusStream;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isSharingLocation = false;
  Position? _currentPosition;
  DateTime? _lastUiUpdate;

  final Map<String, Future<Map<String, String>>> _detailsCache = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startAlarmChecker();
    _checkAndForceGPS();
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    _positionStream?.cancel();
    _gpsStatusStream?.cancel();
    super.dispose();
  }

  Future<Map<String, String>> _getWalkDetails(String walkId, String ownerId, String petId) {
    if (_detailsCache.containsKey(walkId)) {
      return _detailsCache[walkId]!;
    }

    final future = Future.wait([
      FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
      FirebaseFirestore.instance.collection('pets').doc(petId).get(),
    ]).then<Map<String, String>>((results) {
      final ownerData = results[0].data() as Map<String, dynamic>?;
      final petData = results[1].data() as Map<String, dynamic>?;

      return {
        'ownerName': ownerData?['name']?.toString() ?? 'Dueño',
        'petName': petData?['name']?.toString() ?? 'Mascota',
        'homeLat': ownerData?['homeLat']?.toString() ?? '',
        'homeLng': ownerData?['homeLng']?.toString() ?? '',
        'address': ownerData?['address']?.toString() ?? '',
        'locationReference': ownerData?['locationReference']?.toString() ?? '',
      };
    });

    _detailsCache[walkId] = future;
    return future;
  }

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
      _listenToGpsChanges();
    }
  }

  void _showGpsRequiredDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Row(children: [
            Icon(Icons.location_off, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('📍 GPS Requerido')
          ]),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                await Geolocator.openLocationSettings();
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
    if (_isSharingLocation) return;
    setState(() => _isSharingLocation = true);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // ✅ Máxima precisión
        distanceFilter: 5, // ✅ Cambiado a 5 metros para que se actualice al caminar
      ),
    ).listen((Position position) async {
      print('📍 Nueva ubicación: ${position.latitude}, ${position.longitude}'); // ✅ Debug

      final now = DateTime.now();
      if (_lastUiUpdate == null || now.difference(_lastUiUpdate!).inSeconds >= 2) {
        setState(() {
          _currentPosition = position;
          _lastUiUpdate = now;
        });
      }

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('walks')
            .where('walkerId', isEqualTo: widget.walkerId)
            .where('status', whereIn: ['accepted', 'arrived', 'in_progress'])
            .get();

        for (var doc in snapshot.docs) {
          await doc.reference.update({
            'walkerLat': position.latitude,
            'walkerLng': position.longitude,
            'lastLocationUpdate': FieldValue.serverTimestamp(),
            'locationHistory': FieldValue.arrayUnion([
              // ✅ CORREGIDO: Firestore NO permite serverTimestamp() dentro de
              // arrays. Antes esto lanzaba excepción y TODO el update fallaba,
              // por eso el GPS nunca se actualizaba ni se dibujaba el trayecto.
              {'lat': position.latitude, 'lng': position.longitude, 'timestamp': Timestamp.now()}
            ]),
          });
          print('✅ Historial de ubicación actualizado en Firestore'); // ✅ Debug
        }
      } catch (e) {
        // Sin este try/catch el error era silencioso y el GPS parecía "muerto".
        // Si falta el índice compuesto (walkerId + status), el error incluye
        // un link para crearlo automáticamente en Firebase Console.
        print('❌ Error al actualizar ubicación en Firestore: $e');
      }
    });
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notificationsPlugin.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));
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
        final alarmTime = scheduledTime.subtract(const Duration(minutes: 5));

        if (now.isAfter(alarmTime) && data['alarmNotified'] != true) {
          const androidDetails = AndroidNotificationDetails(
            'walk_alarm_channel',
            'Alarma de Paseo',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
          );
          await _notificationsPlugin.show(
            doc.id.hashCode,
            ' ¡Faltan 5 minutos!',
            'Prepárate para iniciar el paseo',
            const NotificationDetails(android: androidDetails),
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

  Future<void> _initiateCall(String ownerId, String ownerName, String walkId, bool isVideo) async {
    final callId = FirebaseFirestore.instance.collection('calls').doc().id;

    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).set({
        'callId': callId,
        'callerId': widget.walkerId,
        'receiverId': ownerId,
        'callerName': 'Paseador',
        'walkId': walkId,
        'isVideo': isVideo,
        'status': 'ringing',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: callId,
            walkId: walkId,
            isCaller: true,
            otherUserName: ownerName,
            otherUserId: ownerId,
            currentUserId: widget.walkerId,
            isVideoCall: isVideo,
            isWalker: true,
          ),
        ),
      );

      if (mounted) {
        await FirebaseFirestore.instance.collection('calls').doc(callId).update({'status': 'ended'});
      }
    } catch (e) {
      print('❌ Error al iniciar llamada: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar la llamada: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _completeWalk(String walkId) async {
    _positionStream?.cancel();
    setState(() => _isSharingLocation = false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Finalizar paseo?'),
        content: const Text('Al confirmar, se generará el cobro, se aplicarán las retenciones de ley y el saldo entrará en garantía por 7 días.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, finalizar')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final walkDoc = await FirebaseFirestore.instance.collection('walks').doc(walkId).get();
      final walkData = walkDoc.data()!;
      final finalAmount = (walkData['finalAmount'] as num?)?.toDouble() ?? 0.0;
      final tip = (walkData['tipAmount'] as num?)?.toDouble() ?? 0.0;
      final totalAmount = finalAmount + tip;

      final settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('financial').get();
      final commission = (settingsDoc.data()?['platformCommission'] as num?)?.toDouble() ?? 21.0;

      await WalletService().processWalkPayment(
        walkId: walkId,
        walkerId: widget.walkerId,
        totalAmount: totalAmount,
        platformCommissionPercent: commission,
        completedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('walks').doc(walkId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Paseo finalizado. Pago procesado y en período de garantía.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmArrival(String walkId) async {
    await FirebaseFirestore.instance.collection('walks').doc(walkId).update({
      'status': 'arrived',
      'walkerArrived': true,
      'arrivedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 ¡Llegada confirmada! El dueño ha sido notificado.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _startWalk(String walkId) async {
    await FirebaseFirestore.instance.collection('walks').doc(walkId).update({
      'status': 'in_progress',
      'startedAt': FieldValue.serverTimestamp(),
      'walkerArrived': true,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚶 ¡Paseo iniciado! El cronómetro ha comenzado.'), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildMiniMap(double ownerLat, double ownerLng, String walkId, List<dynamic>? locationHistory) {
    final bool hasValidDestination = (ownerLat != 19.4326 || ownerLng != -99.1332);

    final double centerLat = hasValidDestination ? ownerLat : (_currentPosition?.latitude ?? 19.4326);
    final double centerLng = hasValidDestination ? ownerLng : (_currentPosition?.longitude ?? -99.1332);

    Set<Marker> markers = {
      if (hasValidDestination)
        Marker(
          markerId: const MarkerId('home'),
          position: LatLng(ownerLat, ownerLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Domicilio'),
        ),
      if (_currentPosition != null)
        Marker(
          markerId: MarkerId('walker_$walkId'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
        ),
    };

    // ✅ CORRECCIÓN: Dibujar línea del recorrido
    Set<Polyline> polylines = {};
    if (locationHistory != null && locationHistory.isNotEmpty) {
      final points = <LatLng>[];
      for (var point in locationHistory) {
        if (point['lat'] != null && point['lng'] != null) {
          points.add(LatLng(point['lat'].toDouble(), point['lng'].toDouble()));
        }
      }
      if (points.isNotEmpty) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: Colors.blue,
            width: 4,
          ),
        );
      }
    }

    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(centerLat, centerLng), zoom: 14),
          markers: markers,
          polylines: polylines, // ✅ Agregado para mostrar la línea
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myWalksStream = FirebaseFirestore.instance
        .collection('walks')
        .where('walkerId', isEqualTo: widget.walkerId)
        .where('status', whereIn: ['accepted', 'arrived', 'in_progress'])
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('Mis Paseos Activos', style: GoogleFonts.poppins(color: Colors.white)),
        leading: null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Cerrar sesión?'),
                  content: const Text('Se detendrá el seguimiento de ubicación y volverás a la pantalla de inicio de sesión.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sí, salir'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await AuthService().signOut();
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(Icons.my_location, color: _isSharingLocation ? Colors.white : Colors.redAccent, size: 20),
                const SizedBox(width: 4),
                Text(
                  _isSharingLocation ? 'GPS ON' : 'GPS OFF',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isSharingLocation ? Colors.white : Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: myWalksStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No tienes paseos activos', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await AuthService().signOut();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Cerrar sesión y volver a intentar'),
                )
              ]),
            );
          }

          final docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final timeA = (a.data() as Map<String, dynamic>)['scheduledTime'] as Timestamp?;
            final timeB = (b.data() as Map<String, dynamic>)['scheduledTime'] as Timestamp?;
            if (timeA == null || timeB == null) return 0;
            return timeA.compareTo(timeB);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final walk = WalkModel.fromMap(data, doc.id);
              final durationMinutes = data['durationMinutes'] ?? 50;

              double ownerLat = 19.4326;
              double ownerLng = -99.1332;

              DateTime? startedAt;
              if (data['startedAt'] != null) {
                startedAt = (data['startedAt'] as Timestamp).toDate();
              } else if (data['scheduledTime'] != null) {
                startedAt = (data['scheduledTime'] as Timestamp).toDate();
              }

              return FutureBuilder<Map<String, String>>(
                future: _getWalkDetails(walk.id, walk.ownerId, walk.petId),
                builder: (context, detailsSnapshot) {
                  if (detailsSnapshot.hasError) {
                    return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Error al cargar detalles'))));
                  }
                  if (!detailsSnapshot.hasData) {
                    return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())));
                  }

                  final details = detailsSnapshot.data!;
                  final ownerName = details['ownerName']!;
                  final petName = details['petName']!;
                  final address = details['address']!;
                  final reference = details['locationReference']!;

                  if (details['homeLat'] != null && details['homeLat']!.isNotEmpty) {
                    ownerLat = double.tryParse(details['homeLat']!) ?? ownerLat;
                  }
                  if (details['homeLng'] != null && details['homeLng']!.isNotEmpty) {
                    ownerLng = double.tryParse(details['homeLng']!) ?? ownerLng;
                  }

                  final locationHistory = data['locationHistory'] as List<dynamic>?;

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
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(ownerName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(' $petName', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ]),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: walk.status == 'in_progress' ? Colors.green.shade100 : (walk.status == 'arrived' ? Colors.blue.shade100 : Colors.blue.shade100),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  walk.status == 'in_progress' ? 'EN PROGRESO' : (walk.status == 'arrived' ? 'LLEGÓ AL DOMICILIO' : 'CONFIRMADO'),
                                  style: TextStyle(
                                    color: walk.status == 'in_progress' ? Colors.green.shade800 : Colors.blue.shade800,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildMiniMap(ownerLat, ownerLng, walk.id, locationHistory),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(children: [
                                        Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${walk.scheduledTime.day}/${walk.scheduledTime.month}/${walk.scheduledTime.year}',
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                        )
                                      ]),
                                    ),
                                    Expanded(
                                      child: Row(children: [
                                        Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${walk.scheduledTime.hour}:${walk.scheduledTime.minute.toString().padLeft(2, '0')} hrs',
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                        )
                                      ]),
                                    ),
                                    if (walk.status == 'in_progress' && startedAt != null) ...[
                                      CountdownTimerWidget(startTime: startedAt, durationMinutes: durationMinutes),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                                        child: Text('Pendiente', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                      )
                                    ]
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (address.isNotEmpty) ...[
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
                                    child: Text('📝 Ref: $reference', style: TextStyle(fontSize: 12, color: Colors.orange.shade600, fontStyle: FontStyle.italic)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (walk.status == 'accepted') ...[
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmArrival(walk.id),
                                icon: const Icon(Icons.home_work, size: 18),
                                label: Text('Llegué al domicilio', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          if (walk.status == 'arrived') ...[
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.icon(
                                onPressed: () => _startWalk(walk.id),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: Text('Iniciar Paseo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
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
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          chatId: chatId,
                                          currentUserId: widget.walkerId,
                                          otherUserId: walk.ownerId,
                                          isWalker: true,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                  label: Text('Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                      ),
                                      builder: (context) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Selecciona el tipo de llamada',
                                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(height: 16),
                                            ListTile(
                                              leading: const Icon(Icons.videocam, color: Colors.blue, size: 30),
                                              title: Text('Videollamada', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                              subtitle: const Text('Con cámara y micrófono'),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _initiateCall(walk.ownerId, ownerName, walk.id, true);
                                              },
                                            ),
                                            const Divider(),
                                            ListTile(
                                              leading: const Icon(Icons.call, color: Colors.green, size: 30),
                                              title: Text('Llamada de Audio', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                              subtitle: const Text('Solo micrófono'),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _initiateCall(walk.ownerId, ownerName, walk.id, false);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.call, size: 16),
                                  label: Text('Llamar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: ElevatedButton.icon(
                                  onPressed: () => _completeWalk(walk.id),
                                  icon: const Icon(Icons.done_all, size: 16),
                                  label: Text('Fin', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
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
