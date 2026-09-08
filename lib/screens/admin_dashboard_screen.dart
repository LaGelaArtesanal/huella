import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'admin_walkers_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_financial_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String adminId;
  const AdminDashboardScreen({super.key, required this.adminId});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: Text('Panel de Administración', style: GoogleFonts.poppins(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _logout(context)),
        ],
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenido, Administrador 👑', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
            const SizedBox(height: 8),
            Text('Controla las operaciones, verificaciones y finanzas de la app.', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 32),

            _buildQuickCard(
              icon: Icons.verified_user,
              iconColor: Colors.green,
              title: 'Gestionar Paseadores',
              subtitle: 'Revisar documentos y aprobar cuentas',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminWalkersScreen())),
            ),
            const SizedBox(height: 16),

            _buildQuickCard(
              icon: Icons.attach_money,
              iconColor: Colors.orange,
              title: 'Configuración de Precios',
              subtitle: 'Modificar la tarifa base del servicio',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen())),
            ),
            const SizedBox(height: 16),

            _buildQuickCard(
              icon: Icons.account_balance,
              iconColor: Colors.blue,
              title: 'Panel Financiero',
              subtitle: 'Ver ingresos, comisiones y estadísticas',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinancialScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.purple),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text('Administración', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('huella', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user, color: Colors.purple),
            title: const Text('Gestionar Paseadores'),
            subtitle: const Text('Aprobar/Bloquear cuentas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminWalkersScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_money, color: Colors.purple),
            title: const Text('Configuración de Precios'),
            subtitle: const Text('Tarifa base'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance, color: Colors.purple),
            title: const Text('Panel Financiero'),
            subtitle: const Text('Ingresos y comisiones'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinancialScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión'),
            onTap: () {
              Navigator.pop(context);
              _logout(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(backgroundColor: iconColor.withOpacity(0.1), radius: 28, child: Icon(icon, color: iconColor, size: 28)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}