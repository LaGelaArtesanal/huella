import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/walk_model.dart';
import 'chat_screen.dart';
import 'call_screen.dart';

class ActiveWalkScreen extends StatefulWidget {
  final String walkId;
  final String ownerId;
  final String walkerId;

  const ActiveWalkScreen({
    super.key,
    required this.walkId,
    required this.ownerId,
    required this.walkerId,
  });

  @override
  State<ActiveWalkScreen> createState() => _ActiveWalkScreenState();
}

class _ActiveWalkScreenState extends State<ActiveWalkScreen> {
  GoogleMapController? _mapController;
  final List<LatLng> _routePoints = [];
  LatLng _currentPosition = const LatLng(19.4326, -99.1332);
  Timer? _timer;
  int _elapsedSeconds = 0;
  String _status = 'walking';
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenToWalkUpdates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_status == 'walking' || _status == 'in_progress') {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _listenToWalkUpdates() {
    FirebaseFirestore.instance.collection('walks').doc(widget.walkId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data()!;
      setState(() {
        _status = data['status'] ?? 'walking';
        if (data['locationHistory'] != null && data['locationHistory'] is List) {
          _routePoints.clear();
          for (var point in data['locationHistory']) {
            if (point['lat'] != null && point['lng'] != null) {
              _routePoints.add(LatLng(point['lat'].toDouble(), point['lng'].toDouble()));
            }
          }
          _updatePolyline();
          if (_routePoints.isNotEmpty) {
            _currentPosition = _routePoints.last;
            _fitMapToRoute();
          }
        } else if (data['walkerLat'] != null && data['walkerLng'] != null) {
          final newPos = LatLng(data['walkerLat'].toDouble(), data['walkerLng'].toDouble());
          if (_routePoints.isEmpty || _routePoints.last != newPos) {
            _routePoints.add(newPos);
            _updatePolyline();
          }
          _currentPosition = newPos;
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 16));
        }
      });
    });
  }

  void _updatePolyline() {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: Colors.deepOrange,
          width: 5,
          patterns: _status == 'walking' || _status == 'in_progress'
              ? [PatternItem.dash(20), PatternItem.gap(10)]
              : [],
        ),
      };
    });
  }

  void _fitMapToRoute() {
    if (_routePoints.length < 2) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _routePoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
        _routePoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        _routePoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
        _routePoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  // ✅ FUNCIÓN PARA INICIAR LA LLAMADA (Adaptada para el DUEÑO)
  Future<void> _initiateCall(String walkerId, String walkerName, String walkId, bool isVideo) async {
    final callId = FirebaseFirestore.instance.collection('calls').doc().id;

    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).set({
        'callId': callId,
        'callerId': widget.ownerId,     // ✅ El dueño llama
        'receiverId': walkerId,         // ✅ El paseador recibe
        'callerName': 'Dueño',
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
            otherUserName: walkerName,
            otherUserId: walkerId,
            currentUserId: widget.ownerId,
            isVideoCall: isVideo,
            isWalker: false, // ✅ El dueño NO es paseador
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Text('Paseo en Curso', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 15),
            markers: {
              Marker(
                markerId: const MarkerId('walker'),
                position: _currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                infoWindow: const InfoWindow(title: 'Ubicación del paseo'),
              )
            },
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_routePoints.isNotEmpty) _fitMapToRoute();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 16, left: 16, right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tiempo transcurrido', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text(_formatTime(_elapsedSeconds), style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: _status == 'completed' ? Colors.green.shade100 : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                              _status == 'completed' ? '✅ Completado' : '🚶 Paseando',
                              style: TextStyle(
                                  color: _status == 'completed' ? Colors.green.shade800 : Colors.blue.shade800,
                                  fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _elapsedSeconds > 0 ? (_elapsedSeconds / 3000).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.deepOrange,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                        chatId: '${widget.ownerId}_${widget.walkerId}',
                        currentUserId: widget.ownerId,
                        otherUserId: widget.walkerId,
                        isWalker: false,
                      )));
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text('Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 8),

                // ✅ AQUÍ ESTÁ EL BOTÓN DE LLAMAR CON EL SELECTOR (COPIADO DEL PASEADOR)
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // 1. Obtener datos del paseador
                      final walkerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.walkerId).get();
                      final walkerName = walkerDoc.data()?['name'] ?? 'Paseador';

                      if (!mounted) return;

                      // 2. Mostrar el selector (Modal)
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
                              Text('Selecciona el tipo de llamada', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.videocam, color: Colors.blue, size: 30),
                                title: Text('Videollamada', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                subtitle: const Text('Con cámara y micrófono'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _initiateCall(widget.walkerId, walkerName, widget.walkId, true); // ✅ Llama a la función
                                },
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.call, color: Colors.green, size: 30),
                                title: Text('Llamada de Audio', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                subtitle: const Text('Solo micrófono'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _initiateCall(widget.walkerId, walkerName, widget.walkId, false); // ✅ Llama a la función
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
                        backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),

                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reportando incidente...'), backgroundColor: Colors.red));
                    },
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: Text('Ayuda', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}