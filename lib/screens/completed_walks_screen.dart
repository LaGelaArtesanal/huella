import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/rate_review_dialog.dart';

class CompletedWalksScreen extends StatefulWidget {
  final String ownerId;
  const CompletedWalksScreen({super.key, required this.ownerId});

  @override
  State<CompletedWalksScreen> createState() => _CompletedWalksScreenState();
}

class _CompletedWalksScreenState extends State<CompletedWalksScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Text('Paseos Realizados', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('walks')
            .where('ownerId', isEqualTo: widget.ownerId)
            .where('status', isEqualTo: 'completed')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error al cargar: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final walks = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'completed' && data['ownerId'] == widget.ownerId;
          }).toList();

          if (walks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Aún no tienes paseos completados',
                      style: GoogleFonts.poppins(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: walks.length,
            itemBuilder: (context, index) {
              final walk = walks[index];
              final data = walk.data() as Map<String, dynamic>;
              final isRated = data['isRated'] == true;
              final walkerId = data['walkerId'] ?? '';
              final petName = data['petName'] ?? 'Mascota';
              final walkerName = data['walkerName'] ?? data['ownerName'] ?? 'Paseador';

              final basePrice = (data['basePrice'] as num?)?.toDouble() ?? 100.0;
              final priceMultiplier = (data['priceMultiplier'] as num?)?.toDouble() ?? 1.0;
              final finalAmount = (data['finalAmount'] as num?)?.toDouble() ?? (basePrice * priceMultiplier);

              final durationMinutes = data['durationMinutes'] ?? 0;
              final pickupAddress = data['pickupAddress'] ?? data['address'] ?? 'Dirección no especificada';

              final createdAt = data['createdAt'] != null
                  ? (data['createdAt'] as Timestamp).toDate()
                  : DateTime.now();
              final startedAt = data['startedAt'] != null
                  ? (data['startedAt'] as Timestamp).toDate()
                  : null;
              final completedAt = data['completedAt'] != null
                  ? (data['completedAt'] as Timestamp).toDate()
                  : DateTime.now();

              // ✅ 1. PROCESAR EL HISTORIAL DE UBICACIÓN PARA LA POLYLINE
              List<LatLng> routePoints = [];
              final locationHistory = data['locationHistory'];

              if (locationHistory != null && locationHistory is List) {
                for (var point in locationHistory) {
                  if (point is Map && point['lat'] != null && point['lng'] != null) {
                    routePoints.add(LatLng(point['lat'].toDouble(), point['lng'].toDouble()));
                  }
                }
              }

              // ✅ 2. DETERMINAR EL CENTRO DEL MAPA (Prioridad: Ruta > Ubicación Paseador > Destino > CDMX)
              double mapLat = (data['ownerLat'] ?? data['pickupLat'] ?? 19.4326).toDouble();
              double mapLng = (data['ownerLng'] ?? data['pickupLng'] ?? -99.1332).toDouble();

              if (routePoints.isNotEmpty) {
                // Si hay ruta, centrar en el último punto (final del paseo)
                mapLat = routePoints.last.latitude;
                mapLng = routePoints.last.longitude;
              } else if (data['walkerLat'] != null && data['walkerLng'] != null) {
                // Si no hay ruta completa, usar la última ubicación registrada del paseador
                mapLat = (data['walkerLat'] as num).toDouble();
                mapLng = (data['walkerLng'] as num).toDouble();
              }

              // ✅ 3. CREAR EL CONJUNTO DE POLYLINES
              Set<Polyline> polylines = {};
              if (routePoints.length >= 2) {
                polylines.add(
                  Polyline(
                    polylineId: const PolylineId('walk_route'),
                    points: routePoints,
                    color: Colors.deepOrange, // Color de la marca de la app
                    width: 4,
                  ),
                );
              }

              return FutureBuilder<DocumentSnapshot>(
                future: walkerId.isNotEmpty
                    ? FirebaseFirestore.instance.collection('users').doc(walkerId).get()
                    : Future.value(null),
                builder: (context, walkerSnapshot) {
                  final walkerDisplayName = walkerSnapshot.hasData && walkerSnapshot.data!.exists
                      ? (walkerSnapshot.data!.data() as Map<String, dynamic>)['name'] ?? walkerName
                      : walkerName;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Paseo con $walkerDisplayName',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                                    Text('🐶 $petName',
                                        style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ✅ 4. MAPA CON POLYLINE Y MARCADOR ACTUALIZADO
                          Container(
                            height: 150, // Un poco más alto para ver mejor la ruta
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(mapLat, mapLng),
                                  zoom: routePoints.isNotEmpty ? 14 : 15, // Zoom un poco más abierto si hay ruta
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId('walk_location'),
                                    position: LatLng(mapLat, mapLng),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                      routePoints.isNotEmpty ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
                                    ),
                                    infoWindow: InfoWindow(
                                      title: routePoints.isNotEmpty ? 'Fin del recorrido' : 'Ubicación del paseo',
                                    ),
                                  ),
                                },
                                polylines: polylines, // ✅ AQUÍ SE DIBUJA LA LÍNEA
                                myLocationEnabled: false,
                                zoomControlsEnabled: false,
                                mapToolbarEnabled: false,
                                compassEnabled: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 24),

                          _buildDetailRow(Icons.access_time, 'Duración', '$durationMinutes minutos'),
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.calendar_today, 'Fecha',
                              '${completedAt.day}/${completedAt.month}/${completedAt.year}'),
                          const SizedBox(height: 12),
                          if (startedAt != null) ...[
                            _buildDetailRow(Icons.schedule, 'Hora de inicio',
                                '${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')}'),
                            const SizedBox(height: 12),
                          ],
                          _buildDetailRow(Icons.location_on, 'Punto de encuentro', pickupAddress),
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.attach_money, 'Monto total',
                              '\$${finalAmount.toStringAsFixed(2)} MXN',
                              valueColor: Colors.green.shade700),

                          const Divider(height: 24),

                          if (isRated) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber.shade700, size: 24),
                                  const SizedBox(width: 8),
                                  Text('¡Ya calificaste este paseo!',
                                      style: GoogleFonts.poppins(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      )),
                                ],
                              ),
                            )
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => RateReviewDialog(
                                      walkId: walk.id,
                                      reviewerId: widget.ownerId,
                                      reviewedId: walkerId,
                                      reviewedName: walkerDisplayName,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.star_border, color: Colors.white, size: 22),
                                label: Text('Calificar y Dejar Propina',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            )
                          ],
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

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.grey[900],
                  )),
            ],
          ),
        ),
      ],
    );
  }
}