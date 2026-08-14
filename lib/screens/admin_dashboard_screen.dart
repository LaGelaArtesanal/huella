import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();
  String _selectedFilter = 'all'; // all, pending, blocked, walkers, owners

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Text('Panel Admin - Huella',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card, color: Colors.white),
            tooltip: 'Generar Token Admin',
            onPressed: _showGenerateTokenDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros rápidos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'Todos', value: 'all', selected: _selectedFilter == 'all'),
                  _FilterChip(label: 'Paseadores Pendientes', value: 'pending', selected: _selectedFilter == 'pending'),
                  _FilterChip(label: 'Bloqueados', value: 'blocked', selected: _selectedFilter == 'blocked'),
                  _FilterChip(label: 'Solo Paseadores', value: 'walkers', selected: _selectedFilter == 'walkers'),
                  _FilterChip(label: 'Solo Dueños', value: 'owners', selected: _selectedFilter == 'owners'),
                ].map((chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = chip.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: chip.selected ? Colors.orange : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(chip.label,
                          style: TextStyle(
                            color: chip.selected ? Colors.white : Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          )),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),

          // Lista de usuarios
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _adminService.getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay usuarios registrados'));
                }

                var users = snapshot.data!;

                // Aplicar filtros
                if (_selectedFilter == 'pending') {
                  users = users.where((u) => u.role == 'walker' && !u.isVerified).toList();
                } else if (_selectedFilter == 'blocked') {
                  users = users.where((u) => u.isBlocked).toList();
                } else if (_selectedFilter == 'walkers') {
                  users = users.where((u) => u.role == 'walker').toList();
                } else if (_selectedFilter == 'owners') {
                  users = users.where((u) => u.role == 'owner').toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(user.role),
                          child: Icon(_getRoleIcon(user.role), color: Colors.white),
                        ),
                        title: Text(user.name,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${user.email} • ${user.role.toUpperCase()}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _StatusBadge(
                                  label: user.isVerified ? 'Verificado ✅' : 'Pendiente ⏳',
                                  color: user.isVerified ? Colors.green : Colors.orange,
                                ),
                                if (user.isBlocked) ...[
                                  const SizedBox(width: 8),
                                  _StatusBadge(label: 'BLOQUEADO 🚫', color: Colors.red),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => _handleUserAction(user, value),
                          itemBuilder: (context) => [
                            if (user.role == 'walker' && !user.isVerified)
                              const PopupMenuItem(value: 'approve', child: Text('Aprobar Documentos')),
                            if (user.role == 'walker' && user.isVerified)
                              const PopupMenuItem(value: 'reject', child: Text('Revocar Verificación')),
                            const PopupMenuItem(value: 'block', child: Text('Bloquear Usuario')),
                            if (user.isBlocked)
                              const PopupMenuItem(value: 'unblock', child: Text('Desbloquear Usuario')),
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

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.purple;
      case 'temp_admin': return Colors.indigo;
      case 'walker': return Colors.blue;
      default: return Colors.orange;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings;
      case 'temp_admin': return Icons.badge;
      case 'walker': return Icons.directions_walk;
      default: return Icons.pets;
    }
  }

  void _handleUserAction(UserModel user, String action) async {
    switch (action) {
      case 'approve':
        await _adminService.updateVerification(user.uid, true);
        _showSnackBar('✅ ${user.name} aprobado como paseador verificado');
        break;
      case 'reject':
        await _adminService.updateVerification(user.uid, false);
        _showSnackBar(' Verificación revocada para ${user.name}');
        break;
      case 'block':
        await _adminService.updateUserBlockStatus(user.uid, true);
        _showSnackBar('🚫 ${user.name} ha sido BLOQUEADO');
        break;
      case 'unblock':
        await _adminService.updateUserBlockStatus(user.uid, false);
        _showSnackBar('✅ ${user.name} desbloqueado');
        break;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.deepOrange),
    );
  }

  void _showGenerateTokenDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generar Token Admin Temporal'),
        content: const Text('Se generará un token válido por 30 días para contratar personal temporal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final token = await _adminService.generateAdminToken('main_admin');
              Navigator.pop(ctx);
              _showTokenResult(token);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: const Text('Generar Token'),
          ),
        ],
      ),
    );
  }

  void _showTokenResult(String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Token Generado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Comparte este código con el nuevo admin temporal:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: SelectableText(token,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            ),
            const SizedBox(height: 12),
            const Text('Este token expira en 30 días.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

class _FilterChip {
  final String label;
  final String value;
  final bool selected;
  const _FilterChip({required this.label, required this.value, required this.selected});
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}