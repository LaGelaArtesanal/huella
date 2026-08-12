import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:excel/excel.dart' as excel;
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();
  String _selectedFilter = 'all';
  bool _isExporting = false;
  String _currentRole = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentRole();
  }

  Future<void> _loadCurrentRole() async {
    final user = AuthService().currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _currentRole = doc.data()?['role'] ?? '';
          });
        }
      } catch (e) {
        print('Error cargando rol: $e');
      }
    }
  }

  bool get isSuperAdmin => _currentRole == 'admin';

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

  // Generar token: SOLO SUPER ADMIN
  Future<void> _generateAdminToken() async {
    if (!isSuperAdmin) return;

    try {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = Random();
      final token = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();

      await FirebaseFirestore.instance.collection('admin_tokens').doc(token).set({
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'usedBy': null,
        'isActive': true,
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('✅ Token Creado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Comparte este código con el nuevo administrador:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Text(
                  token,
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.deepOrange),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al crear token: $e')));
    }
  }

  // Exportar Excel
  Future<void> _exportToExcel(List<UserModel> users) async {
    setState(() => _isExporting = true);
    try {
      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheetObject = excelFile['Usuarios_Huella'];
      List<String> headers = ['Nombre', 'Email', 'Rol', 'Verificado', 'Bloqueado', 'Teléfono', 'Dirección', 'Referencia'];
      sheetObject.appendRow(headers.map((h) => excel.TextCellValue(h)).toList());

      for (var user in users) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.exists ? doc.data()! : {};
        sheetObject.appendRow([
          excel.TextCellValue(user.name), excel.TextCellValue(user.email), excel.TextCellValue(user.role),
          excel.TextCellValue(user.isVerified ? 'Sí' : 'No'), excel.TextCellValue(user.isBlocked ? 'Sí' : 'No'),
          excel.TextCellValue(data['phone'] ?? ''), excel.TextCellValue(data['address'] ?? ''),
          excel.TextCellValue(data['locationReference'] ?? ''),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'reporte_huella_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      File('${directory.path}/$fileName')..createSync(recursive: true)..writeAsBytesSync(excelFile.encode()!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Excel guardado en: ${directory.path}/$fileName'), duration: const Duration(seconds: 5)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al exportar: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ✅ FUNCIÓN ACTUALIZADA: Revisión completa de documentos
  void _reviewDocuments(UserModel user) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) return;

      final idUrl = data['idDocumentUrl'];
      final selfieUrl = data['selfieUrl'];
      final addressUrl = data['addressProofUrl'];
      final birthUrl = data['birthCertUrl'];
      final fiscalUrl = data['fiscalConstUrl'];
      final curp = data['curp'] ?? 'No registrado';
      final rfc = data['rfc'] ?? 'No registrado';

      if (idUrl == null && selfieUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Este usuario aún no ha subido documentos.')));
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Revisar: ${user.name}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DATOS FISCALES
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🆔 CURP:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      Text(curp.toString(), style: GoogleFonts.poppins(fontSize: 14, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text('💼 RFC:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      Text(rfc.toString(), style: GoogleFonts.poppins(fontSize: 14, letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // IDENTIDAD
                const Text('Documento Oficial:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                idUrl != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(idUrl, fit: BoxFit.cover, loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator())))
                    : Container(height: 100, color: Colors.grey[200], alignment: Alignment.center, child: const Text('Sin documento')),

                const SizedBox(height: 16),
                const Text('Selfie:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                selfieUrl != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(selfieUrl, fit: BoxFit.cover))
                    : Container(height: 100, color: Colors.grey[200], alignment: Alignment.center, child: const Text('Sin selfie')),

                const SizedBox(height: 16),

                // DOMICILIO Y LEGAL
                if (addressUrl != null) ...[
                  const Text('Comprobante Domicilio:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(addressUrl, fit: BoxFit.cover)),
                  const SizedBox(height: 16),
                ],

                if (birthUrl != null) ...[
                  const Text('Acta Nacimiento:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(birthUrl, fit: BoxFit.cover)),
                  const SizedBox(height: 16),
                ],

                // FISCAL (PDF)
                if (fiscalUrl != null) ...[
                  const Text('Constancia Fiscal (PDF):', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL del PDF copiada al portapapeles'), duration: Duration(seconds: 2)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.red.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: Colors.red.shade700, size: 32),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Ver/Descargar Constancia', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold))),
                          Icon(Icons.open_in_new, color: Colors.red.shade700),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'isVerified': true,
                  'canWork': true,
                  'verificationStatus': 'approved',
                  'verifiedAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(ctx);
                _showSnackBar('✅ ${user.name} VERIFICADO y habilitado para trabajar');
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Aprobar'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar docs: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Text('Panel Admin - Huella', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.add_card, color: Colors.white),
              tooltip: 'Generar Token Admin',
              onPressed: _generateAdminToken,
            ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download, color: Colors.white),
            tooltip: 'Exportar a Excel',
            onPressed: _isExporting ? null : () async {
              final snapshot = await FirebaseFirestore.instance.collection('users').get();
              final allUsers = snapshot.docs.map((doc) {
                try { return UserModel.fromMap(doc.data()); }
                catch (e) { return null; }
              }).whereType<UserModel>().toList();
              await _exportToExcel(allUsers);
            },
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _logout(context)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _buildFilterChip('Todos', 'all'), _buildFilterChip('Pendientes', 'pending'),
                _buildFilterChip('Bloqueados', 'blocked'), _buildFilterChip('Paseadores', 'walkers'),
                _buildFilterChip('Dueños', 'owners'),
              ]),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _adminService.getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orange));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No hay usuarios registrados'));

                var users = snapshot.data!;
                if (_selectedFilter == 'pending') users = users.where((u) => u.role == 'walker' && !u.isVerified).toList();
                else if (_selectedFilter == 'blocked') users = users.where((u) => u.isBlocked).toList();
                else if (_selectedFilter == 'walkers') users = users.where((u) => u.role == 'walker').toList();
                else if (_selectedFilter == 'owners') users = users.where((u) => u.role == 'owner').toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    List<PopupMenuItem<String>> menuItems = [];

                    if (user.role == 'walker' && !user.isVerified) {
                      menuItems.add(const PopupMenuItem(value: 'approve', child: Text('Aprobar Rápido')));
                      menuItems.add(const PopupMenuItem(value: 'review_docs', child: Text(' Revisar Documentos')));
                    }

                    if (user.role == 'walker' && user.isVerified) {
                      menuItems.add(const PopupMenuItem(value: 'reject', child: Text('Revocar Verificación')));
                    }

                    if (!user.isBlocked) {
                      menuItems.add(const PopupMenuItem(value: 'block', child: Text('Bloquear Usuario')));
                    } else {
                      menuItems.add(const PopupMenuItem(value: 'unblock', child: Text('Desbloquear Usuario')));
                    }

                    return Card(
                      elevation: 2, margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(backgroundColor: _getRoleColor(user.role), child: Icon(_getRoleIcon(user.role), color: Colors.white)),
                        title: Text(user.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${user.email} • ${user.role.toUpperCase()}'),
                          const SizedBox(height: 4),
                          Row(children: [
                            _StatusBadge(label: user.isVerified ? 'Verificado ✅' : 'Pendiente ', color: user.isVerified ? Colors.green : Colors.orange),
                            if (user.isBlocked) ...[const SizedBox(width: 8), _StatusBadge(label: 'BLOQUEADO 🚫', color: Colors.red)],
                          ]),
                        ]),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => _handleUserAction(user, value),
                          itemBuilder: (context) => menuItems,
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: isSelected ? Colors.orange : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade300)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.orange.shade900, fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    ));
  }

  Color _getRoleColor(String role) {
    switch (role) { case 'admin': return Colors.purple; case 'temp_admin': return Colors.indigo; case 'walker': return Colors.blue; default: return Colors.orange; }
  }

  IconData _getRoleIcon(String role) {
    switch (role) { case 'admin': return Icons.admin_panel_settings; case 'temp_admin': return Icons.badge; case 'walker': return Icons.directions_walk; default: return Icons.pets; }
  }

  void _handleUserAction(UserModel user, String action) async {
    if ((action == 'block' || action == 'unblock') &&
        (user.role == 'admin' || user.role == 'temp_admin') &&
        !isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚫 No tienes permiso para modificar cuentas de administradores.'), backgroundColor: Colors.red),
      );
      return;
    }

    switch (action) {
      case 'approve':
        await _adminService.updateVerification(user.uid, true);
        _showSnackBar('✅ ${user.name} aprobado'); break;
      case 'reject':
        await _adminService.updateVerification(user.uid, false);
        _showSnackBar('️ Verificación revocada para ${user.name}'); break;
      case 'block':
        await _adminService.updateUserBlockStatus(user.uid, true);
        _showSnackBar('🚫 ${user.name} ha sido BLOQUEADO'); break;
      case 'unblock':
        await _adminService.updateUserBlockStatus(user.uid, false);
        _showSnackBar('✅ ${user.name} desbloqueado'); break;
      case 'review_docs':
        _reviewDocuments(user);
        break;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.deepOrange));
  }
}

class _StatusBadge extends StatelessWidget {
  final String label; final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}