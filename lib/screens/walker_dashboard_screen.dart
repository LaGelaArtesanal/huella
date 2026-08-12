import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'walker_requests_screen.dart';
import 'my_walks_screen.dart';
import 'edit_walker_profile_screen.dart';
import 'upload_documents_screen.dart';

class WalkerDashboardScreen extends StatefulWidget {
  final String walkerId;
  const WalkerDashboardScreen({super.key, required this.walkerId});

  @override
  State<WalkerDashboardScreen> createState() => _WalkerDashboardScreenState();
}

class _WalkerDashboardScreenState extends State<WalkerDashboardScreen> {

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
    // 🔒 GUARDIÁN DE VERIFICACIÓN
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.walkerId)
          .snapshots(),
      builder: (context, snapshot) {
        // Mientras carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.blue)),
          );
        }

        // Si hay error o usuario no existe
        if (!snapshot.hasData || !snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) _logout(context);
          });
          return const Scaffold(body: Center(child: Text('Error de sesión')));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final isVerified = userData['isVerified'] ?? false;

        // 🚫 SI NO ESTÁ VERIFICADO -> Pantalla de Documentos
        if (!isVerified) {
          // ✅ CORREGIDO: Sin parámetros extra
          return const UploadDocumentsScreen();
        }

        // ✅ SI ESTÁ VERIFICADO -> Dashboard Normal
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¡Hola, Paseador! 👋',
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            const SizedBox(height: 8),
            Text('¿Qué quieres hacer hoy?',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 32),

            Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: Colors.green.shade100, radius: 28, child: Icon(Icons.calendar_today, color: Colors.green.shade700, size: 28)),
                title: Text('Mis Paseos Activos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Ver dirección, hora y chatear con dueños', style: TextStyle(fontSize: 13)),
                trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyWalksScreen(walkerId: widget.walkerId))),
              ),
            ),

            Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: Colors.orange.shade100, radius: 28, child: Icon(Icons.inbox, color: Colors.orange.shade700, size: 28)),
                title: Text('Solicitudes de Paseo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Acepta nuevos paseos disponibles', style: TextStyle(fontSize: 13)),
                trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalkerRequestsScreen(walkerId: widget.walkerId))),
              ),
            ),

            Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: Colors.blue.shade100, radius: 28, child: Icon(Icons.person_outline, color: Colors.blue.shade700, size: 28)),
                title: Text('Mi Perfil', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Editar información y zona de cobertura', style: TextStyle(fontSize: 13)),
                trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditWalkerProfileScreen(userId: widget.walkerId))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}