import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/auth_service.dart';
import '../config/pricing_config.dart';
import 'login_screen.dart';
import 'walker_requests_screen.dart';
import 'my_walks_screen.dart';
import 'edit_walker_profile_screen.dart';
import 'upload_documents_screen.dart';
import 'walker_earnings_screen.dart';
import '../widgets/blinking_card.dart';
import '../services/alert_service.dart';
import '../widgets/demand_heatmap.dart';

class WalkerDashboardScreen extends StatefulWidget {
  final String walkerId;
  const WalkerDashboardScreen({super.key, required this.walkerId});

  @override
  State<WalkerDashboardScreen> createState() => _WalkerDashboardScreenState();
}

class _WalkerDashboardScreenState extends State<WalkerDashboardScreen> {
  bool _hasNewRequests = false;
  DateTime? _lastAlertTime;
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _listenForNewRequests();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Permisos de ubicación denegados permanentemente');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() => _currentPosition = position);
      }
    } catch (e) {
      print('❌ Error al obtener ubicación: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _listenForNewRequests() {
    FirebaseFirestore.instance
        .collection('walks')
        .where('status', whereIn: ['pending', 'paid'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final latestWalk = snapshot.docs.first;
        final walkCreatedAt = (latestWalk.data()['createdAt'] as Timestamp?)?.toDate();

        if (walkCreatedAt != null) {
          if (_lastAlertTime == null || walkCreatedAt.isAfter(_lastAlertTime!)) {
            if (mounted) {
              setState(() {
                _hasNewRequests = true;
                _lastAlertTime = DateTime.now();
              });
            }
            AlertService.triggerAlert();
          }
        }
      } else {
        if (mounted) {
          setState(() => _hasNewRequests = false);
        }
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.walkerId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blue)));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) _logout(context);
          });
          return const Scaffold(body: Center(child: Text('Error de sesión')));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final isVerified = userData['isVerified'] ?? false;

        if (!isVerified) {
          return const UploadDocumentsScreen();
        }

        return _buildDashboardContent();
      },
    );
  }

  Widget _buildDashboardContent() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Panel de Paseador', style: GoogleFonts.poppins(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Hola, Paseador! 👋',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Qué quieres hacer hoy?',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Tarjeta de Precio Base
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.blue.shade700, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tarifa Base del Servicio',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${PricingConfig.basePrice.toStringAsFixed(2)} MXN',
                            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            '(Fijado por la administración)',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tarjeta de Solicitudes (Parpadea solo si hay nuevas)
            BlinkingCard(
              shouldBlink: _hasNewRequests,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: _hasNewRequests ? Colors.red.shade100 : Colors.orange.shade100,
                  radius: 28,
                  child: Icon(
                    Icons.inbox,
                    color: _hasNewRequests ? Colors.red.shade700 : Colors.orange.shade700,
                    size: 28,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Solicitudes de Paseo',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_hasNewRequests) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                        child: const Text(
                          '¡NUEVO!',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text('Acepta nuevos paseos disponibles', style: TextStyle(fontSize: 13)),
                trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
                onTap: () {
                  setState(() => _hasNewRequests = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WalkerRequestsScreen(walkerId: widget.walkerId)),
                  );
                },
              ),
            ),

            // Mis Paseos Activos
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  radius: 28,
                  child: Icon(Icons.calendar_today, color: Colors.green.shade700, size: 28),
                ),
                title: Text('Mis Paseos Activos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Ver dirección, hora y chatear con dueños', style: TextStyle(fontSize: 13)),
                trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyWalksScreen(walkerId: widget.walkerId))),
              ),
            ),

            // Mis Ganancias
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  radius: 28,
                  child: Icon(Icons.account_balance_wallet, color: Colors.green.shade700, size: 28),
                ),
                title: Text('Mis Ganancias', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Ver balance, propinas y historial', style: TextStyle(fontSize: 13)),
                trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalkerEarningsScreen(walkerId: widget.walkerId))),
              ),
            ),

            // Mi Perfil
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  radius: 28,
                  child: Icon(Icons.person_outline, color: Colors.blue.shade700, size: 28),
                ),
                title: Text('Mi Perfil', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Editar información y zona de cobertura', style: TextStyle(fontSize: 13)),
                trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditWalkerProfileScreen(userId: widget.walkerId))),
              ),
            ),

            // ✅ SECCIÓN DE MAPA DE DEMANDA EN TIEMPO REAL (Limpia y sin duplicados)
            const SizedBox(height: 24),
            const Divider(thickness: 1, color: Colors.grey),
            const SizedBox(height: 16),

            // Mostrar loading o el mapa (El widget ya incluye su propio título interno)
            if (_isLoadingLocation)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DemandHeatmapWidget(
                initialPosition: LatLng(
                  _currentPosition?.latitude ?? 19.4326,
                  _currentPosition?.longitude ?? -99.1332,
                ),
                radius: 500,
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}