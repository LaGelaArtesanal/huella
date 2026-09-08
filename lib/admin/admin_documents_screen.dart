import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDocumentsScreen extends StatelessWidget {
  const AdminDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revisión Manual de Documentos', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Documentos rechazados por la IA que requieren tu aprobación manual.', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // Filtramos usuarios que sean paseadores y tengan algún documento rechazado
                final pendingUsers = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['role'] != 'walker') return false;
                  final docs = data['documents'] as Map<String, dynamic>? ?? {};
                  return docs.values.any((d) => (d as Map<String, dynamic>)['status'] == 'rejected');
                }).toList();

                if (pendingUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
                        const SizedBox(height: 16),
                        Text('¡Todo limpio!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        const SizedBox(height: 8),
                        Text('No hay documentos pendientes de revisión manual.', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: pendingUsers.length,
                  itemBuilder: (context, index) {
                    final user = pendingUsers[index].data() as Map<String, dynamic>;
                    final name = user['name'] ?? 'Sin nombre';
                    final docs = user['documents'] as Map<String, dynamic>? ?? {};

                    final rejectedDocs = docs.entries.where((e) => (e.value as Map<String, dynamic>)['status'] == 'rejected').toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: const CircleAvatar(child: Icon(Icons.warning, color: Colors.orange)),
                        title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        subtitle: Text('${rejectedDocs.length} documento(s) rechazado(s)'),
                        children: rejectedDocs.map((entry) {
                          final docType = entry.key;
                          final reason = (entry.value as Map<String, dynamic>)['reason'] ?? 'Sin motivo';
                          return ListTile(
                            title: Text(docType.replaceAll('_', ' ').toUpperCase()),
                            subtitle: Text('Motivo IA: $reason', style: TextStyle(color: Colors.red.shade700)),
                            trailing: TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Función de aprobación manual en desarrollo')),
                                );
                              },
                              child: const Text('Aprobar', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
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
}