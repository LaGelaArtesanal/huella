import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadDocumentsScreen extends StatefulWidget {
  const UploadDocumentsScreen({super.key});

  @override
  State<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen> {
  final _picker = ImagePicker();
  final _curpController = TextEditingController();
  final _rfcController = TextEditingController();
  bool _isUploading = false;

  // Archivos seleccionados temporalmente
  File? _ineFile;
  File? _selfieFile;
  File? _addressFile;
  File? _birthFile;
  File? _fiscalFile;

  // Configuración de los documentos requeridos
  final List<Map<String, dynamic>> _docConfig = [
    {'id': 'ine_front', 'label': 'INE / IFE (Frente) *', 'icon': Icons.credit_card, 'isPdf': false, 'fileGetter': (s) => s._ineFile, 'fileSetter': (s, f) => s._ineFile = f},
    {'id': 'selfie', 'label': 'Selfie Actual (Rostro claro) *', 'icon': Icons.camera_alt, 'isPdf': false, 'fileGetter': (s) => s._selfieFile, 'fileSetter': (s, f) => s._selfieFile = f},
    {'id': 'acta_nacimiento', 'label': 'Acta de Nacimiento', 'icon': Icons.child_care, 'isPdf': false, 'fileGetter': (s) => s._birthFile, 'fileSetter': (s, f) => s._birthFile = f},
    {'id': 'comprobante_domicilio', 'label': 'Comprobante de Domicilio', 'icon': Icons.home, 'isPdf': false, 'fileGetter': (s) => s._addressFile, 'fileSetter': (s, f) => s._addressFile = f},
    {'id': 'constancia_fiscal', 'label': 'Constancia de Situación Fiscal (PDF) *', 'icon': Icons.receipt_long, 'isPdf': true, 'fileGetter': (s) => s._fiscalFile, 'fileSetter': (s, f) => s._fiscalFile = f},
  ];

  @override
  void dispose() {
    _curpController.dispose();
    _rfcController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(bool isPdf, Function(File) onPicked) async {
    if (isPdf) {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.single.path != null) {
        onPicked(File(result.files.single.path!));
      }
    } else {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        onPicked(File(pickedFile.path));
      }
    }
  }

  Future<void> _uploadSingleDocument(String docId, File file, bool isPdf) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      final extension = isPdf ? 'pdf' : 'jpg';
      final storageRef = FirebaseStorage.instance.ref().child('walker_documents/${user.uid}/$docId.$extension');

      await storageRef.putFile(file);

      // Actualizamos el estado a "pending" para que la UI lo refleje inmediatamente
      // La Cloud Function lo cambiará a "approved" o "rejected" en unos segundos
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'curp': _curpController.text.trim().toUpperCase(),
        'rfc': _rfcController.text.trim().toUpperCase(),
        'documents': {
          docId: {
            'status': 'pending',
            'reason': 'Procesando con IA...',
          }
        }
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Documento subido. La IA lo está verificando...'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al subir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submitInitialData() async {
    if (_ineFile == null || _selfieFile == null || _fiscalFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debes subir al menos INE, Selfie y Constancia Fiscal'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_curpController.text.trim().length < 18 || _rfcController.text.trim().length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Verifica que CURP (18 chars) y RFC (12+ chars) sean correctos'), backgroundColor: Colors.orange),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      // Guardar datos iniciales del usuario
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'curp': _curpController.text.trim().toUpperCase(),
        'rfc': _rfcController.text.trim().toUpperCase(),
        'verificationStatus': 'pending',
        'documentsSubmittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Subir cada documento seleccionado
      for (var doc in _docConfig) {
        final file = doc['fileGetter'](this) as File?;
        if (file != null) {
          await _uploadSingleDocument(doc['id'], file, doc['isPdf']);
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error general: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 8), Text('Cerrar sesión')]),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              // Aquí puedes navegar a tu LoginScreen: Navigator.pushReplacement(...)
            },
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('No hay sesión iniciada')));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: const Text('Verificación de Paseador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), tooltip: 'Cerrar sesión', onPressed: _confirmLogout),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final documents = userData['documents'] as Map<String, dynamic>? ?? {};
          final canAcceptWalks = userData['canAcceptWalks'] == true;

          // Actualizar controladores si están vacíos y hay datos
          if (_curpController.text.isEmpty && userData['curp'] != null) {
            _curpController.text = userData['curp'];
          }
          if (_rfcController.text.isEmpty && userData['rfc'] != null) {
            _rfcController.text = userData['rfc'];
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canAcceptWalks) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade300)),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user, color: Colors.green, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('¡Cuenta Verificada!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Ya puedes aceptar solicitudes de paseo.', style: TextStyle(color: Colors.green, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const Text('Completa tu perfil para comenzar a trabajar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('La IA verificará tus documentos automáticamente en segundos.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 32),

                _buildTextField(_curpController, 'CURP *', Icons.badge, maxLength: 18),
                const SizedBox(height: 16),
                _buildTextField(_rfcController, 'RFC *', Icons.numbers, maxLength: 13),
                const SizedBox(height: 32),

                // Generar tarjetas de documentos dinámicamente
                ..._docConfig.map((doc) {
                  final docId = doc['id'] as String;
                  final docData = documents[docId] as Map<String, dynamic>? ?? {};
                  final status = docData['status'] as String? ?? 'pending';
                  final reason = docData['reason'] as String? ?? '';
                  final currentFile = doc['fileGetter'](this) as File?;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildDocumentCard(
                      label: doc['label'],
                      icon: doc['icon'],
                      isPdf: doc['isPdf'],
                      status: status,
                      reason: reason,
                      currentFile: currentFile,
                      isApproved: status == 'approved',
                      onPick: () => _pickFile(doc['isPdf'], (file) {
                        doc['fileSetter'](this, file);
                        setState(() {});
                      }),
                      onUpload: () => _uploadSingleDocument(docId, currentFile!, doc['isPdf']), // ✅ CORREGIDO: currentFile! en lugar de currentFile ?? file
                    ),
                  );
                }).toList(),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_isUploading || canAcceptWalks) ? null : _submitInitialData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isUploading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enviar / Actualizar Documentación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int? maxLength}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepOrange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDocumentCard({
    required String label,
    required IconData icon,
    required bool isPdf,
    required String status,
    required String reason,
    required File? currentFile,
    required bool isApproved,
    required VoidCallback onPick,
    required VoidCallback onUpload,
  }) {
    Color cardColor;
    Color borderColor;
    Widget statusWidget;

    switch (status) {
      case 'approved':
        cardColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        statusWidget = const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 6),
            Text('Verificado por IA', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        );
        break;
      case 'rejected':
        cardColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        statusWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cancel, color: Colors.red, size: 20),
                SizedBox(width: 6),
                Text('Rechazado', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Motivo: $reason', style: const TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        );
        break;
      default: // pending o sin estado
        cardColor = Colors.grey.shade50;
        borderColor = Colors.grey.shade300;
        statusWidget = const Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.grey, size: 20),
            SizedBox(width: 6),
            Text('Pendiente de revisión', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepOrange, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              if (isApproved) const Icon(Icons.lock, color: Colors.green, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          statusWidget,
          const SizedBox(height: 12),

          // Área de selección de archivo
          if (!isApproved)
            GestureDetector(
              onTap: onPick,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.deepOrange.shade200, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: Colors.deepOrange, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      currentFile != null ? 'Archivo seleccionado (Toca para cambiar)' : 'Toca para seleccionar archivo',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 60,
              alignment: Alignment.center,
              child: const Text('Este documento ya fue aprobado y no puede modificarse.', style: TextStyle(color: Colors.green, fontSize: 13, fontStyle: FontStyle.italic)),
            ),

          // Botón de subir si hay archivo seleccionado y no está aprobado
          if (!isApproved && currentFile != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Subir y Verificar con IA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}