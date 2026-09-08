import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class DemandHeatmapWidget extends StatefulWidget {
  final LatLng initialPosition;
  final double radius;

  const DemandHeatmapWidget({
    super.key,
    required this.initialPosition,
    this.radius = 500,
  });

  @override
  State<DemandHeatmapWidget> createState() => _DemandHeatmapWidgetState();
}

class _DemandHeatmapWidgetState extends State<DemandHeatmapWidget> {
  GoogleMapController? _mapController;
  Set<Circle> _heatmapCircles = {};
  Set<Marker> _demandMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadHeatmapData();
  }

  Future<void> _loadHeatmapData() async {
    try {
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));

      final snapshot = await FirebaseFirestore.instance
          .collection('walk_requests_heatmap')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(twoHoursAgo))
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _heatmapCircles = {};
            _demandMarkers = {};
          });
        }
        return;
      }

      final clusters = <_Cluster>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['lat'] as double;
        final lng = data['lng'] as double;
        final point = LatLng(lat, lng);

        bool addedToCluster = false;
        for (var cluster in clusters) {
          if (_distanceBetween(cluster.center, point) <= widget.radius) {
            cluster.points.add(point);
            addedToCluster = true;
            break;
          }
        }

        if (!addedToCluster) {
          clusters.add(_Cluster(center: point, points: [point]));
        }
      }

      final circles = <Circle>{};
      final markers = <Marker>{};

      for (var cluster in clusters) {
        final intensity = cluster.points.length;
        final color = _getDemandColor(intensity);
        final radius = _getCircleRadius(intensity);

        circles.add(Circle(
          circleId: CircleId(cluster.center.toString()),
          center: cluster.center,
          radius: radius,
          fillColor: color.withOpacity(0.3),
          strokeColor: color.withOpacity(0.6),
          strokeWidth: 2,
        ));

        markers.add(Marker(
          markerId: MarkerId('demand_${cluster.center}'),
          position: cluster.center,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            intensity >= 5 ? BitmapDescriptor.hueGreen :
            intensity >= 3 ? BitmapDescriptor.hueYellow :
            BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: 'Zona de ${_getDemandLevel(intensity)} demanda',
            snippet: '$intensity solicitud(es) en las últimas 2 horas',
          ),
        ));
      }

      if (mounted) {
        setState(() {
          _heatmapCircles = circles;
          _demandMarkers = markers;
        });
      }

    } catch (e) {
      print('❌ Error al cargar heatmap: $e');
    }
  }

  Color _getDemandColor(int intensity) {
    if (intensity >= 5) return Colors.green;
    if (intensity >= 3) return Colors.yellow;
    return Colors.red;
  }

  String _getDemandLevel(int intensity) {
    if (intensity >= 5) return 'ALTA';
    if (intensity >= 3) return 'MEDIA';
    return 'BAJA';
  }

  double _getCircleRadius(int intensity) {
    if (intensity >= 5) return 800;
    if (intensity >= 3) return 500;
    return 300;
  }

  double _distanceBetween(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final dLat = (point2.latitude - point1.latitude) * pi / 180;
    final dLng = (point2.longitude - point1.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Título y subtítulo integrados (autocontenido)
        Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mapa de Demanda',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Zonas con más solicitudes en tiempo real',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),

        // ✅ Leyenda del mapa con Wrap (a prueba de overflow)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _legendItem(Colors.green, 'Alta (5+)'),
              _legendItem(Colors.yellow, 'Media (3-4)'),
              _legendItem(Colors.red, 'Baja (1-2)'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ✅ Mapa de calor
        Container(
          height: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.initialPosition,
                zoom: 13,
              ),
              circles: _heatmapCircles,
              markers: _demandMarkers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ✅ Botón para actualizar centrado
        Center(
          child: TextButton.icon(
            onPressed: _loadHeatmapData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Actualizar mapa'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          softWrap: true,
        ),
      ],
    );
  }
}

class _Cluster {
  final LatLng center;
  final List<LatLng> points;

  _Cluster({required this.center, required this.points});
}