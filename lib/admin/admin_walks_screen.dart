import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminWalksScreen extends StatelessWidget {
  const AdminWalksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Paseos Activos', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text('Botón de Pánico Disponible', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('walks')
                  .where('status', whereIn: ['accepted', 'arrived', 'in_progress'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final walks = snapshot.data!.docs;

                if (walks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_walk, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No hay paseos activos en este momento.', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: walks.length,
                  itemBuilder: (context, index) {
                    final walk = walks[index].data() as Map<String, dynamic>;
                    final status = walk['status'] ?? 'unknown';
                    final createdAt = (walk['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                    Color statusColor;
                    switch (status) {
                      case 'in_progress': statusColor = Colors.green; break;
                      case 'arrived': statusColor = Colors.blue; break;
                      default: statusColor = Colors.orange;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(Icons.pets, color: statusColor),
                        ),
                        title: Text('Paseo #${walks[index].id.substring(0, 8)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(createdAt)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              tooltip: 'Cancelar y Reembolsar (Pánico)',
                              onPressed: () => _showPanicDialog(context, walks[index].id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPanicDialog(BuildContext context, String walkId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('¿Cancelar Paseo?')]),
        content: const Text('Esto cancelará el paseo inmediatamente, notificará a ambas partes y procesará un reembolso total al dueño.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, cerrar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('walks').doc(walkId).update({'status': 'cancelled_by_admin'});
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paseo cancelado y reembolso procesado.'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Sí, Cancelar y Reembolsar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}