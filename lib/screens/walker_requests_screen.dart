import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk_model.dart';
import 'my_walks_screen.dart';
import '../services/alert_service.dart'; // ✅ Import del servicio de alertas

class WalkerRequestsScreen extends StatefulWidget {
  final String walkerId;
  const WalkerRequestsScreen({super.key, required this.walkerId});

  @override
  State<WalkerRequestsScreen> createState() => _WalkerRequestsScreenState();
}

class _WalkerRequestsScreenState extends State<WalkerRequestsScreen> {
  bool _hasAlerted = false; // ✅ Para evitar que suene infinitamente

  Future<void> _acceptWalk(WalkModel walk) async {
    try {
      final activeWalksSnapshot = await FirebaseFirestore.instance
          .collection('walks')
          .where('walkerId', isEqualTo: widget.walkerId)
          .where('status', whereIn: ['accepted', 'in_progress'])
          .count()
          .get();

      if ((activeWalksSnapshot.count ?? 0) >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Límite alcanzado: Solo puedes tener 2 paseos activos.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('walks').doc(walk.id).update({
        'walkerId': widget.walkerId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Paseo aceptado. Cargando detalles...'), backgroundColor: Colors.green)
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MyWalksScreen(walkerId: widget.walkerId)),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al aceptar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsStream = FirebaseFirestore.instance
        .collection('walks')
        .where('status', whereIn: ['pending', 'paid'])
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Solicitudes Disponibles', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: requestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // ✅ ACTIVAR ALERTA CUANDO LLEGAN SOLICITUDES
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty && !_hasAlerted) {
            _hasAlerted = true;
            AlertService.triggerAlert(); // 🔊 Sonido + Vibración
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Resetear la alerta si no hay paseos, para que suene la próxima vez que llegue uno
            _hasAlerted = false;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No hay solicitudes disponibles',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Las solicitudes aparecerán aquí cuando los dueños las creen.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            );
          }

          final allRequestsData = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'walk': WalkModel.fromMap(data, doc.id),
              'data': data,
            };
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allRequestsData.length,
            itemBuilder: (context, index) {
              final item = allRequestsData[index];
              final walk = item['walk'] as WalkModel;
              final data = item['data'] as Map<String, dynamic>;

              final basePrice = (data['basePrice'] as num?)?.toDouble() ?? 100.0;
              final priceMultiplier = (data['priceMultiplier'] as num?)?.toDouble() ?? 1.0;
              final sizeMultiplier = (data['sizeMultiplier'] as num?)?.toDouble() ?? 1.0;
              final finalAmount = (data['finalAmount'] as num?)?.toDouble() ?? (basePrice * priceMultiplier * sizeMultiplier);

              return FutureBuilder<List<DocumentSnapshot>>(
                future: Future.wait([
                  FirebaseFirestore.instance.collection('pets').doc(walk.petId).get(),
                  FirebaseFirestore.instance.collection('users').doc(walk.ownerId).get(),
                ]),
                builder: (context, detailsSnapshot) {
                  String petName = 'Mascota';
                  String petBreed = '';
                  String ownerName = 'Dueño';

                  if (detailsSnapshot.hasData) {
                    final petData = detailsSnapshot.data![0].data() as Map<String, dynamic>?;
                    final ownerData = detailsSnapshot.data![1].data() as Map<String, dynamic>?;

                    if (petData != null) {
                      petName = petData['name'] ?? 'Mascota';
                      petBreed = petData['breed'] ?? '';
                    }
                    if (ownerData != null) {
                      ownerName = ownerData['name'] ?? 'Dueño';
                    }
                  }

                  final bool isScheduled = data['isScheduled'] == true;
                  final String typeLabel = isScheduled ? '📅 AGENDADO' : '⚡ INMEDIATO';
                  final Color labelColor = isScheduled ? Colors.purple.shade100 : Colors.red.shade100;
                  final Color textColor = isScheduled ? Colors.purple.shade800 : Colors.red.shade800;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(backgroundColor: Colors.blue.shade100, child: Icon(Icons.person, color: Colors.blue.shade700)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ownerName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                    Text('$petName • $petBreed', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: labelColor,
                                    borderRadius: BorderRadius.circular(12)
                                ),
                                child: Text(
                                    typeLabel,
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold
                                    )
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade700), const SizedBox(width: 8), Text('${walk.scheduledTime.day}/${walk.scheduledTime.month}/${walk.scheduledTime.year}', style: const TextStyle(fontWeight: FontWeight.w500))]),
                                const SizedBox(height: 8),
                                Row(children: [Icon(Icons.access_time, size: 16, color: Colors.blue.shade700), const SizedBox(width: 8), Text('${walk.scheduledTime.hour}:${walk.scheduledTime.minute.toString().padLeft(2, '0')} hrs', style: const TextStyle(fontWeight: FontWeight.w500))]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Icon(Icons.attach_money, size: 16, color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                      'Total a recibir: \$${finalAmount.toStringAsFixed(2)} MXN',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16)
                                  )
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _acceptWalk(walk),
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text('Aceptar Paseo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
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