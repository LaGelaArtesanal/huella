import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/auth_service.dart';
import 'my_pets_screen.dart';
import 'owner_profile_screen.dart';
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
    print(' Usuario logueado: ${widget.userName} (ID: ${widget.userId})');
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
        .where('status', whereIn: ['pending', 'accepted', 'arrived', 'in_progress'])
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ SALUDO CORREGIDO
                  Text(
                    '¡Hola, ${widget.userName.isNotEmpty ? widget.userName : "Usuario"}! 👋',
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gestiona tus mascotas y solicita paseos.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 24),

                  // ✅ TARJETA MODERNA DE ESTADO (Corregida para evitar overflow)
                  ModernWalkStatusCard(ownerId: widget.userId),

                  const SizedBox(height: 20),

                  // ✅ BOTÓN DE ESTADO DEL PASEO
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('walks')
                        .where('ownerId', isEqualTo: widget.userId)
                        .where('status', whereIn: ['pending', 'accepted', 'arrived', 'in_progress'])
                        .limit(1)
                        .snapshots(),
                    builder: (context, walkSnapshot) {
                      if (walkSnapshot.hasData && walkSnapshot.data!.docs.isNotEmpty) {
                        final activeWalk = walkSnapshot.data!.docs.first;
                        final status = activeWalk['status'] ?? 'pending';

                        String btnText = 'Ver Estado del Paseo';
                        if (status == 'accepted' || status == 'arrived' || status == 'in_progress') {
                          btnText = 'Ver Paseo en Tiempo Real';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => WalkTrackingScreen(
                                walkId: activeWalk.id,
                                ownerId: widget.userId,
                                walkerId: activeWalk['walkerId'] ?? '',
                              )));
                            },
                            icon: const Icon(Icons.map_outlined, size: 22),
                            label: Text(
                              btnText,
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // ✅ BOTONES PRINCIPALES (Rediseñados para evitar overflow)
                  _buildModernButton(
                    icon: Icons.pets,
                    label: 'Mis Mascotas',
                    color: Colors.orange,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MyPetsScreen(ownerId: widget.userId)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildModernButton(
                    icon: Icons.person,
                    label: 'Mi Perfil de Dueño',
                    color: Colors.purple,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OwnerProfileScreen(userId: widget.userId, userName: widget.userName),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildModernButton(
                    icon: Icons.pets_outlined,
                    label: 'Solicitar Paseo',
                    color: Colors.blue,
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
                  ),
                  const SizedBox(height: 12),
                  _buildModernButton(
                    icon: Icons.history,
                    label: 'Paseos Realizados',
                    color: Colors.teal,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompletedWalksScreen(ownerId: widget.userId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MÉTODO AUXILIAR PARA BOTONES MODERNOS
  Widget _buildModernButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ==========================================
// WIDGET: Tarjeta Moderna de Estado del Paseo (Corregida)
// ==========================================
class ModernWalkStatusCard extends StatelessWidget {
  final String ownerId;

  const ModernWalkStatusCard({super.key, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('walks')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', whereIn: ['pending', 'accepted', 'arrived', 'in_progress'])
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final walkData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final status = walkData['status'] ?? 'pending';

        String title = "Buscando paseador...";
        String subtitle = "Tu pago fue exitoso. Notificando a paseadores cercanos.";
        IconData icon = Icons.search;
        Color themeColor = Colors.orange;
        int currentStep = 1;

        if (status == 'accepted') {
          title = "¡Paseador en camino!";
          subtitle = "Un paseador aceptó y va hacia tu domicilio.";
          icon = Icons.directions_walk;
          themeColor = Colors.blue;
          currentStep = 2;
        } else if (status == 'arrived') {
          title = "¡El paseador llegó!";
          subtitle = "Está esperando en tu domicilio.";
          icon = Icons.home_work;
          themeColor = Colors.teal;
          currentStep = 3;
        } else if (status == 'in_progress') {
          title = "Paseo en curso";
          subtitle = "¡Tu mascota está disfrutando el paseo!";
          icon = Icons.pets;
          themeColor = Colors.green;
          currentStep = 4;
        }

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 1.0, end: 1.8),
                            duration: const Duration(seconds: 2),
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return Container(
                                width: 40 * value,
                                height: 40 * value,
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          ),
                          Icon(icon, color: themeColor, size: 24),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  child: Text(
                                    title,
                                    key: ValueKey(title),
                                    style: GoogleFonts.poppins(
                                      color: themeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: themeColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'LIVE',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              subtitle,
                              key: ValueKey(subtitle),
                              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ✅ STEPPER SIMPLIFICADO Y RESPONSIVE
                _buildCompactStepper(currentStep, themeColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactStepper(int currentStep, Color themeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStep(Icons.receipt_long, 'Pedido', 1, currentStep, themeColor),
        _buildStep(Icons.directions_car, 'Camino', 2, currentStep, themeColor),
        _buildStep(Icons.home_work, 'Llegó', 3, currentStep, themeColor),
        _buildStep(Icons.pets, 'Paseo', 4, currentStep, themeColor),
      ],
    );
  }

  Widget _buildStep(IconData icon, String label, int stepNum, int currentStep, Color themeColor) {
    final isActive = stepNum <= currentStep;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? themeColor : Colors.grey.shade200,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [BoxShadow(color: themeColor.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))]
                : null,
          ),
          child: Icon(icon, color: isActive ? Colors.white : Colors.grey.shade400, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? themeColor : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}