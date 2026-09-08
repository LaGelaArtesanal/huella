import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'document_viewer_screen.dart';

class AdminWalkersScreen extends StatefulWidget {
  const AdminWalkersScreen({super.key});

  @override
  State<AdminWalkersScreen> createState() => _AdminWalkersScreenState();
}

class _AdminWalkersScreenState extends State<AdminWalkersScreen> {
  String _filter = 'all';

  Future<void> _updateWalkerStatus(String userId, bool isVerified, bool isBlocked) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isVerified': isVerified,
        'isBlocked': isBlocked,
        'verificationStatus': isVerified ? 'approved' : (isBlocked ? 'blocked' : 'pending'),
        'verifiedAt': isVerified ? FieldValue.serverTimestamp() : null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBlocked ? '🚫 Paseador bloqueado' : (isVerified ? '✅ Paseador aprobado' : 'Actualizado')),
            backgroundColor: isBlocked ? Colors.red : (isVerified ? Colors.green : Colors.blue),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openDocument(String url, String title) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Documento no disponible'), backgroundColor: Colors.orange),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(url: url, title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: Text('Gestionar Paseadores', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // FILTROS
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filtrar por estado:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('Todos', 'all', Colors.grey),
                    _buildFilterChip('⏳ Pendientes', 'pending', Colors.orange),
                    _buildFilterChip('✅ Verificados', 'verified', Colors.green),
                    _buildFilterChip('🚫 Bloqueados', 'blocked', Colors.red),
                  ],
                ),
              ],
            ),
          ),

          // LISTA DESPLEGABLE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'walker').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay paseadores registrados'));
                }

                final walkers = snapshot.data!.docs;

                final filteredWalkers = walkers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['verificationStatus'] ?? 'pending';
                  final isBlocked = data['isBlocked'] ?? false;

                  switch (_filter) {
                    case 'pending': return status == 'pending' && !isBlocked;
                    case 'verified': return status == 'approved' && !isBlocked;
                    case 'blocked': return isBlocked;
                    default: return true;
                  }
                }).toList();

                if (filteredWalkers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No hay resultados para este filtro', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredWalkers.length,
                  itemBuilder: (context, index) {
                    final doc = filteredWalkers[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = doc.id;

                    final name = data['name'] ?? 'Sin nombre';
                    final curp = data['curp'] ?? '';
                    final rfc = data['rfc'] ?? '';

                    final status = data['verificationStatus'] ?? 'pending';
                    final isBlocked = data['isBlocked'] ?? false;

                    // ✅ LECTURA EXACTA Y FORZADA DE LOS CAMPOS DE FIRESTORE
                    final selfieUrl = (data['selfieUrl'] ?? '') as String;
                    final idUrl = (data['idDocumentUrl'] ?? '') as String;
                    final addressProofUrl = (data['addressProofUrl'] ?? '') as String; // ✅ ESTE ES EL CAMPO CLAVE
                    final birthCertUrl = (data['birthCertUrl'] ?? '') as String;
                    final fiscalConstUrl = (data['fiscalConstUrl'] ?? '') as String;

                    final isVerified = status == 'approved';
                    final statusColor = isBlocked ? Colors.red : (isVerified ? Colors.green : Colors.orange);
                    final statusText = isBlocked ? '🚫 BLOQUEADO' : (isVerified ? '✅ VERIFICADO' : '⏳ PENDIENTE');

                    // Contar documentos disponibles
                    int docCount = [selfieUrl, idUrl, addressProofUrl, birthCertUrl, fiscalConstUrl].where((url) => url.isNotEmpty).length;

                    // 🔍 DEBUG: Imprimir en consola para verificar
                    print('🔍 Paseador: $name');
                    print('   - addressProofUrl isEmpty: ${addressProofUrl.isEmpty}');
                    print('   - addressProofUrl value: $addressProofUrl');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(Icons.person, color: statusColor),
                          ),
                          title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text('$statusText • $docCount documentos', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.expand_more, color: Colors.grey),
                          children: [
                            const Divider(),

                            // 1. DATOS FISCALES
                            if (curp.isNotEmpty || rfc.isNotEmpty) ...[
                              Text('Datos Fiscales', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                              const SizedBox(height: 8),
                              if (curp.isNotEmpty) _buildInfoRow('🆔 CURP', curp),
                              if (rfc.isNotEmpty) _buildInfoRow('💼 RFC', rfc),
                              const SizedBox(height: 12),
                            ],

                            // 2. BOTONES DE DOCUMENTOS
                            Text('Documentos Adjuntos', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (selfieUrl.isNotEmpty) _buildDocButton('🤳 Selfie', selfieUrl, Colors.blue),
                                if (idUrl.isNotEmpty) _buildDocButton('🪪 INE/ID', idUrl, Colors.purple),
                                if (addressProofUrl.isNotEmpty) _buildDocButton('🏠 Comprobante', addressProofUrl, Colors.green), // ✅ BOTÓN CORREGIDO
                                if (birthCertUrl.isNotEmpty) _buildDocButton('👶 Acta Nac.', birthCertUrl, Colors.teal),
                                if (fiscalConstUrl.isNotEmpty) _buildDocButton('📄 Constancia', fiscalConstUrl, Colors.orange),
                                if (docCount == 0) Text('Sin documentos subidos', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),

                            // 3. ACCIONES DE ADMIN
                            Row(
                              children: [
                                if (!isVerified && !isBlocked)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _updateWalkerStatus(userId, true, false),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Aprobar'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                                    ),
                                  ),
                                if (!isVerified && !isBlocked) const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateWalkerStatus(userId, isVerified, !isBlocked),
                                    icon: Icon(isBlocked ? Icons.lock_open : Icons.block, size: 18),
                                    label: Text(isBlocked ? 'Desbloquear' : 'Bloquear'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isBlocked ? Colors.orange : Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.w600)),
      selected: isSelected,
      onSelected: (selected) => setState(() => _filter = value),
      backgroundColor: Colors.white,
      selectedColor: color,
      checkmarkColor: Colors.white,
      side: BorderSide(color: color, width: isSelected ? 2 : 1),
    );
  }

  Widget _buildDocButton(String label, String url, Color color) {
    return ElevatedButton.icon(
      onPressed: () => _openDocument(url, label),
      icon: const Icon(Icons.visibility, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildInfoRow(String iconLabel, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(iconLabel, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87))),
        ],
      ),
    );
  }
}