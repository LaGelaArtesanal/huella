import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/auth_service.dart';
import '../main.dart'; // Para LoginScreen
import 'my_pets_screen.dart';
import 'owner_profile_screen.dart';
// NUEVO: Import de la pantalla de solicitud con duración
import 'request_walk_screen.dart';
// NUEVO: Import de la pantalla de rastreo en tiempo real
import 'walk_tracking_screen.dart';
import 'login_screen.dart';

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
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _logout(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
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
                  Icon(Icons.pets, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('¡El paseador ha llegado!',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: Duration(seconds: 4),
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
          // Listener Invisible para notificaciones de llegada
          StreamBuilder<QuerySnapshot>(
            stream: _getActiveWalksStream(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkArrivalNotifications(snapshot.data!);
                });
              }
              return SizedBox.shrink();
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
                  const SizedBox(height: 32),

                  // Botón condicional "Paseo en Curso"
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

                  // CAMBIO: Botón "Solicitar Paseo" que lleva a RequestWalkScreen
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}