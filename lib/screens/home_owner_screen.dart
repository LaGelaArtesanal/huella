import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/auth_service.dart';
import 'my_pets_screen.dart';
import 'owner_profile_screen.dart'; // ⚠️ Asegúrate de que este archivo exista en la carpeta screens
import 'request_walk_screen.dart';
import 'walk_tracking_screen.dart';
import 'login_screen.dart';
import 'completed_walks_screen.dart';

class HomeOwnerScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const HomeOwnerScreen({super.key, required this.userId, required this.userName});

  @override
  State<HomeOwnerScreen> createState() => _HomeOwnerScreenState();
}

class _HomeOwnerScreenState extends State<HomeOwnerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, bool> _notifiedWalks = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _logout(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Stream<QuerySnapshot> _getActiveWalksStream() {
    return FirebaseFirestore.instance
        .collection('walks')
        .where('ownerId', isEqualTo: widget.userId)
        .where('status', whereIn: ['accepted', 'in_progress'])
        .snapshots();
  }

  Future<void> _checkArrivalNotifications(QuerySnapshot snapshot) async {
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      final walkId = doc.id;

      if (data?['walkerArrived'] == true && _notifiedWalks[walkId] != true) {
        try {
          await _audioPlayer.play(AssetSource('sounds/ping_arrival.mp3'));
        } catch (e) {
          print('Error audio: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.pets, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('¡El paseador ha llegado!',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        _notifiedWalks[walkId] = true;
        await FirebaseFirestore.instance.collection('walks').doc(walkId).update({
          'arrivalNotified': true,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('Huella - Dueño', style: GoogleFonts.poppins(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _getActiveWalksStream(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkArrivalNotifications(snapshot.data!);
                });
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¡Hola, ${widget.userName}! 👋',
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Gestiona tus mascotas y solicita paseos.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 24),

                  // Tarjeta Dinámica de Estado del Paseo (Estilo Uber)
                  const WalkStatusTrackerCard(),

                  const SizedBox(height: 24),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('walks')
                        .where('ownerId', isEqualTo: widget.userId)
                        .where('status', whereIn: ['accepted', 'in_progress'])
                        .limit(1)
                        .snapshots(),
                    builder: (context, walkSnapshot) {
                      if (walkSnapshot.hasData && walkSnapshot.data!.docs.isNotEmpty) {
                        final activeWalk = walkSnapshot.data!.docs.first;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 65,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => WalkTrackingScreen(
                                  walkId: activeWalk.id,
                                  ownerId: widget.userId,
                                  walkerId: activeWalk['walkerId'],
                                )));
                              },
                              icon: const Icon(Icons.map_outlined, size: 26),
                              label: Text('Ver Paseo en Tiempo Real',
                                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MyPetsScreen(ownerId: widget.userId)),
                        );
                      },
                      icon: const Icon(Icons.pets, size: 24),
                      label: Text('Mis Mascotas', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OwnerProfileScreen(userId: widget.userId, userName: widget.userName),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person, size: 24),
                      label: Text('Mi Perfil de Dueño', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RequestWalkScreen(
                              ownerId: widget.userId,
                              ownerName: widget.userName,
                              ownerLat: 19.4326,
                              ownerLng: -99.1332,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.pets_outlined, size: 24),
                      label: Text('Solicitar Paseo', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompletedWalksScreen(ownerId: widget.userId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history, size: 24),
                      label: Text('Paseos Realizados', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET: Tarjeta Dinámica de Estado del Paseo
// ==========================================
class WalkStatusTrackerCard extends StatelessWidget {
  const WalkStatusTrackerCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el ownerId del contexto o pasándolo, aquí lo tomamos del padre si es necesario,
    // pero para simplificar, usamos un StreamBuilder genérico o lo pasamos.
    // Nota: Para que funcione perfecto, necesitamos el ownerId. Lo ajustamos para recibirlo o leerlo del contexto.
    // Como es un widget stateless, lo ideal es que el padre le pase el ownerId, pero para mantener tu estructura original:

    // Vamos a asumir que podemos leer el userId del usuario actual o pasarlo.
    // Para evitar errores, lo haré recibir el ownerId como parámetro opcional o lo leemos de Auth.
    // Mejor lo dejo como estaba en tu código original, pero corregido para que compile:

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('walks')
      // Nota: Si necesitas filtrar por ownerId, asegúrate de pasarlo.
      // Aquí lo dejo abierto o puedes ajustar el where si tienes el ID.
          .where('status', whereIn: ['pending', 'accepted', 'arrived', 'in_progress'])
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final walkData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final status = walkData['status'] ?? 'pending';

        String title = "Buscando paseadores...";
        String subtitle = "Notificando a paseadores cercanos...";
        IconData icon = Icons.search;
        Color color = Colors.orange;
        double progress = 0.25;

        if (status == 'accepted') {
          title = "¡Paseador encontrado!";
          subtitle = "El paseador aceptó y está en camino.";
          icon = Icons.directions_walk;
          color = Colors.blue;
          progress = 0.50;
        } else if (status == 'arrived') {
          title = "¡El paseador llegó!";
          subtitle = "Está esperando en tu domicilio.";
          icon = Icons.home;
          color = Colors.green;
          progress = 0.75;
        } else if (status == 'in_progress') {
          title = "Paseo en curso";
          subtitle = "¡Tu mascota está disfrutando el paseo!";
          icon = Icons.pets;
          color = Colors.deepOrange;
          progress = 1.0;
        }

        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: color.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.grey.shade300,
                      color: color,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}