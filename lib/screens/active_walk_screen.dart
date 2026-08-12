import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/walk_model.dart';
import 'chat_screen.dart';

class ActiveWalkScreen extends StatefulWidget {
  final String walkId;
  final String ownerId;
  final String walkerId;

  const ActiveWalkScreen({
    super.key,
    required this.walkId,
    required this.ownerId,
    required this.walkerId
  });

  @override
  State<ActiveWalkScreen> createState() => _ActiveWalkScreenState();
}

class _ActiveWalkScreenState extends State<ActiveWalkScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(19.4326, -99.1332); // Posición inicial CDMX
  Timer? _timer;
  int _elapsedSeconds = 0;
  String _status = 'walking'; // walking, completed, issue

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
      if (_status == 'walking') {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _listenToWalkUpdates() {
    FirebaseFirestore.instance.collection('walks').doc(widget.walkId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data()!;

      // Actualizar estado
      setState(() {
        _status = data['status'] ?? 'walking';

        // Si hay coordenadas del paseador, actualizar mapa
        if (data['walkerLat'] != null && data['walkerLng'] != null) {
          _currentPosition = LatLng(data['walkerLat'], data['walkerLng']);
          _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_currentPosition, 16)
          );
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
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
          // 1. MAPA EN TIEMPO REAL
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 15),
            markers: {
              Marker(
                markerId: const MarkerId('walker'),
                position: _currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                infoWindow: const InfoWindow(title: 'Tu paseador'),
              )
            },
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          // 2. PANEL SUPERIOR DE ESTADO
          Positioned(
            top: 16,
            left: 16,
            right: 16,
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
                            Text('Tiempo transcurrido',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text(_formatTime(_elapsedSeconds),
                                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: _status == 'completed' ? Colors.green.shade100 : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20)
                          ),
                          child: Text(
                              _status == 'completed' ? '✅ Completado' : '🚶 Paseando',
                              style: TextStyle(
                                  color: _status == 'completed' ? Colors.green.shade800 : Colors.blue.shade800,
                                  fontWeight: FontWeight.bold
                              )
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _elapsedSeconds / 3000, // Asumiendo 50 min = 3000 seg
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

          // 3. BOTONES INFERIORES DE ACCIÓN
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
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
                    label: Text('Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Lógica de emergencia
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reportando incidente...'), backgroundColor: Colors.red)
                      );
                    },
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: Text('Ayuda', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
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