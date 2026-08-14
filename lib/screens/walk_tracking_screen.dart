import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'chat_screen.dart';
import 'call_screen.dart';

class WalkTrackingScreen extends StatefulWidget {
  final String walkId;
  final String ownerId;
  final String walkerId;

  const WalkTrackingScreen({
    super.key,
    required this.walkId,
    required this.ownerId,
    required this.walkerId,
  });

  @override
  State<WalkTrackingScreen> createState() => _WalkTrackingScreenState();
}

class _WalkTrackingScreenState extends State<WalkTrackingScreen> {
  GoogleMapController? _mapController;

  // Coordenadas por defecto (CDMX) solo como fallback inicial
  LatLng _walkerPosition = const LatLng(19.4326, -99.1332);
  LatLng _ownerPosition = const LatLng(19.4326, -99.1332);

  Timer? _timer;
  int _elapsedSeconds = 0;
  String _walkStatus = 'accepted';
  DateTime? _startTime;

  bool _isMapMode = true;
  double? _distanceToHome;
  bool _isFirstLocationUpdate = true;
  bool _locationLoaded = false; // ✅ NUEVO: Para saber si ya cargamos la ubicación real

  @override
  void initState() {
    super.initState();
    _loadOwnerLocation();
    _listenToWalkUpdates();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ✅ MEJORADO: Búsqueda inteligente de la ubicación
  Future<void> _loadOwnerLocation() async {
    try {
      double? lat;
      double? lng;

      // 1. Intentar obtener la ubicación desde el documento del paseo
      final walkDoc = await FirebaseFirestore.instance.collection('walks').doc(widget.walkId).get();
      if (walkDoc.exists) {
        final walkData = walkDoc.data()!;
        lat = (walkData['pickupLat'] ?? walkData['latitude'] ?? walkData['lat'])?.toDouble();
        lng = (walkData['pickupLng'] ?? walkData['longitude'] ?? walkData['lng'])?.toDouble();
      }

      // 2. Si no está en el paseo, intentar obtenerla del perfil del dueño
      if (lat == null || lng == null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.ownerId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          lat = (userData['homeLat'] ?? userData['latitude'] ?? userData['lat'])?.toDouble();
          lng = (userData['homeLng'] ?? userData['longitude'] ?? userData['lng'])?.toDouble();
        }
      }

      // 3. Actualizar el estado y centrar el mapa si encontramos coordenadas válidas
      if (lat != null && lng != null) {
        // ✅ TRUCO INFALIBLE: Creamos variables 'double' seguras usando '!'
        final safeLat = lat!;
        final safeLng = lng!;

        setState(() {
          _ownerPosition = LatLng(safeLat, safeLng);
          _locationLoaded = true;
          _calculateDistance();
        });

        // Centrar el mapa en la ubicación del dueño/pickup
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(safeLat, safeLng), 15),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No se encontró la dirección del paseo en la base de datos'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error cargando ubicación: $e');
    }
  }

  void _calculateDistance() {
    // Evitar cálculos con la posición por defecto si aún no hemos cargado la real
    if (!_locationLoaded) return;

    if (_walkerPosition.latitude != 19.4326 || _walkerPosition.longitude != -99.1332) {
      final distance = Geolocator.distanceBetween(
        _ownerPosition.latitude,
        _ownerPosition.longitude,
        _walkerPosition.latitude,
        _walkerPosition.longitude,
      );
      setState(() => _distanceToHome = distance);
    }
  }

  void _listenToWalkUpdates() {
    FirebaseFirestore.instance.collection('walks').doc(widget.walkId).snapshots().listen((doc) {
      if (!doc.exists || !mounted) return;

      final data = doc.data()!;

      setState(() {
        _walkStatus = data['status'] ?? 'accepted';

        if (data['walkerLat'] != null && data['walkerLng'] != null) {
          final newPos = LatLng(data['walkerLat'], data['walkerLng']);
          _walkerPosition = newPos;
          _calculateDistance();

          // Centrar el mapa solo la primera vez que llega la ubicación del paseador
          if (_isFirstLocationUpdate && _mapController != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16));
            _isFirstLocationUpdate = false;
          } else if (_isMapMode && _mapController != null) {
            // Si ya se centró, solo seguimos la posición suavemente
            _mapController!.animateCamera(CameraUpdate.newLatLng(newPos));
          }
        }

        if (data['startedAt'] != null) {
          _startTime = (data['startedAt'] as Timestamp).toDate();
        } else if (data['arrivedAt'] != null && _startTime == null) {
          _startTime = (data['arrivedAt'] as Timestamp).toDate();
        }
      });
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null && _walkStatus != 'completed' && mounted) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  // ✅ Función para generar el ID del chat ordenado (evita errores de permisos por ID incorrecto)
  String _getChatId(String id1, String id2) {
    List<String> ids = [id1, id2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  Widget _buildTextModeView() {
    final progress = _elapsedSeconds / 3000; // Asumimos 50 min (3000 seg) como estándar
    final distanceText = _distanceToHome != null
        ? '${(_distanceToHome! / 1000).toStringAsFixed(2)} km'
        : 'Calculando...';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_walk, size: 64, color: Colors.deepOrange),
                const SizedBox(height: 24),
                Text('Estado del Paseo', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_formatTime(_elapsedSeconds),
                    style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El paseador está a $distanceText de tu casa',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress > 1 ? 1.0 : progress,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.deepOrange,
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${(progress * 100).toInt()}% completado • 50 min estimados',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
    );
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: true, label: Text('Mapa'), icon: Icon(Icons.map, size: 18)),
                ButtonSegment<bool>(value: false, label: Text('Texto'), icon: Icon(Icons.list_alt, size: 18)),
              ],
              selected: {_isMapMode},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() => _isMapMode = newSelection.first);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white.withOpacity(0.9);
                  return Colors.white.withOpacity(0.3);
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) return Colors.deepOrange;
                  return Colors.white;
                }),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isMapMode)
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _ownerPosition, zoom: 14),
              markers: {
                Marker(
                  markerId: const MarkerId('walker'),
                  position: _walkerPosition,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: const InfoWindow(title: 'Tu paseador está aquí'),
                ),
                Marker(
                  markerId: const MarkerId('home'),
                  position: _ownerPosition,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  infoWindow: const InfoWindow(title: 'Tu domicilio'),
                )
              },
              onMapCreated: (controller) {
                _mapController = controller;
                // Si la ubicación ya se cargó antes de que el mapa estuviera listo, centrarlo ahora
                if (_locationLoaded) {
                  controller.animateCamera(CameraUpdate.newLatLngZoom(_ownerPosition, 15));
                }
              },
              myLocationEnabled: false,
              zoomControlsEnabled: true,
            )
          else
            _buildTextModeView(),

          if (_isMapMode)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tiempo transcurrido',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(_formatTime(_elapsedSeconds),
                              style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: _walkStatus == 'completed' ? Colors.green.shade100 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _walkStatus == 'completed' ? Colors.green : Colors.blue.shade200)
                        ),
                        child: Text(
                            _walkStatus == 'completed' ? '✅ Finalizado' : '🚶 En camino',
                            style: TextStyle(
                                color: _walkStatus == 'completed' ? Colors.green.shade800 : Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12
                            )
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),

          // Fila de 3 botones (Chat, Llamar, Ayuda)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Botón Chat
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final chatId = _getChatId(widget.ownerId, widget.walkerId);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                        chatId: chatId,
                        currentUserId: widget.ownerId,
                        otherUserId: widget.walkerId,
                        isWalker: false,
                      )));
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text('Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Botón Llamar Cifrado
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final walkerDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.walkerId)
                          .get();
                      final walkerName = walkerDoc.data()?['name'] ?? 'Paseador';

                      if (!mounted) return;

                      Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
                        callId: widget.walkId,
                        isCaller: true,
                        otherUserName: walkerName,
                        currentUserId: widget.ownerId,
                      )));
                    },
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text('Llamar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Botón Ayuda/Reportar
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('¿Reportar problema?'),
                          content: const Text('Esto alertará al soporte inmediatamente y finalizará el paseo.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('walks').doc(widget.walkId).update({
                                    'issueReported': true,
                                    'status': 'cancelled_issue',
                                  });
                                  if (mounted) {
                                    Navigator.pop(context);
                                    Navigator.pop(context); // Regresar a la pantalla anterior
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Incidente reportado. Soporte notificado.'), backgroundColor: Colors.red)
                                    );
                                  }
                                },
                                child: const Text('Reportar')
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: Text('Ayuda', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
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