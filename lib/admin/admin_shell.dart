import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminShell extends StatefulWidget {
  final String adminEmail;
  const AdminShell({super.key, required this.adminEmail});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Menú lateral
          Container(
            width: 240,
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.pets, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'HUELLA',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Panel Admin',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                ),
                const Divider(color: Colors.white24, height: 32),

                ListTile(
                  leading: const Icon(Icons.dashboard, color: Colors.orange),
                  title: Text('Dashboard', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  tileColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.people, color: Colors.white70),
                  title: Text('Usuarios', style: GoogleFonts.poppins(color: Colors.white70)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pantalla de Usuarios en desarrollo')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.verified_user, color: Colors.white70),
                  title: Text('Documentos IA', style: GoogleFonts.poppins(color: Colors.white70)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pantalla de Documentos en desarrollo')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map, color: Colors.white70),
                  title: Text('Paseos Activos', style: GoogleFonts.poppins(color: Colors.white70)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pantalla de Paseos en desarrollo')),
                    );
                  },
                ),

                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        widget.adminEmail,
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Salir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Text(
                        'Dashboard',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'En línea',
                              style: GoogleFonts.poppins(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.admin_panel_settings, size: 80, color: Colors.orange.shade300),
                        const SizedBox(height: 24),
                        Text(
                          '¡Bienvenido al Panel de Administración!',
                          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aquí podrás gestionar usuarios, documentos y paseos.',
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Las pantallas detalladas están en desarrollo.',
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}