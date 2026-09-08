import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPIs principales
          Row(
            children: [
              Expanded(child: _KpiCard(title: 'Paseos Hoy', icon: Icons.directions_walk, color: Colors.blue, stream: _todayWalksStream())),
              const SizedBox(width: 16),
              Expanded(child: _KpiCard(title: 'Ingresos Hoy', icon: Icons.attach_money, color: Colors.green, stream: _todayRevenueStream())),
              const SizedBox(width: 16),
              Expanded(child: _KpiCard(title: 'Paseadores Activos', icon: Icons.people, color: Colors.orange, stream: _activeWalkersStream())),
              const SizedBox(width: 16),
              Expanded(child: _KpiCard(title: 'Documentos Pendientes', icon: Icons.folder_open, color: Colors.red, stream: _pendingDocsStream())),
            ],
          ),

          const SizedBox(height: 32),

          // Sección de actividad reciente
          Text('Actividad Reciente', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('walks')
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    ...snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'unknown';
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                      Color statusColor;
                      String statusText;
                      IconData statusIcon;

                      switch (status) {
                        case 'completed':
                          statusColor = Colors.green;
                          statusText = 'Completado';
                          statusIcon = Icons.check_circle;
                          break;
                        case 'in_progress':
                          statusColor = Colors.blue;
                          statusText = 'En progreso';
                          statusIcon = Icons.directions_walk;
                          break;
                        case 'pending':
                          statusColor = Colors.orange;
                          statusText = 'Pendiente';
                          statusIcon = Icons.hourglass_empty;
                          break;
                        default:
                          statusColor = Colors.grey;
                          statusText = status;
                          statusIcon = Icons.info;
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(statusIcon, color: statusColor),
                        ),
                        title: Text('Paseo #${doc.id.substring(0, 8)}'),
                        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(createdAt)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: GoogleFonts.poppins(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _todayWalksStream() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return FirebaseFirestore.instance
        .collection('walks')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots();
  }

  Stream<QuerySnapshot> _todayRevenueStream() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return FirebaseFirestore.instance
        .collection('walks')
        .where('status', isEqualTo: 'completed')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots();
  }

  Stream<QuerySnapshot> _activeWalkersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'walker')
        .where('canAcceptWalks', isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _pendingDocsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'walker')
        .snapshots();
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;

  const _KpiCard({required this.title, required this.icon, required this.color, required this.stream});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Text('...', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold));
              }

              int count = snapshot.data!.docs.length;

              // Para ingresos, sumar montos
              if (title == 'Ingresos Hoy') {
                double total = 0;
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final netAmount = (data['netAmount'] as num?)?.toDouble() ?? 0.0;
                  total += netAmount;
                }
                return Text(
                  '\$${total.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold),
                );
              }

              return Text(
                '$count',
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold),
              );
            },
          ),
          Text(
            title,
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}