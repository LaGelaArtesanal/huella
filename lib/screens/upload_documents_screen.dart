import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ⚠️ IMPORTANTE: Descomenta y ajusta esta línea con el nombre real de tu pantalla de login
// import 'tu_carpeta/login_screen.dart';

class UploadDocumentsScreen extends StatefulWidget {
  const UploadDocumentsScreen({super.key});

  @override
  State<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen> {
  // Archivos seleccionados
  File? _idImage;
  File? _selfieImage;
  File? _addressFile;
  File? _birthFile;
  File? _fiscalPdf;

  // Controladores de texto
  final _curpController = TextEditingController();
  final _rfcController = TextEditingController();

  bool _isUploading = false;
  final _picker = ImagePicker();

  // ✅ NUEVO: Función para limpiar el formulario después de subir
  void _clearForm() {
    setState(() {
      _idImage = null;
      _selfieImage = null;
      _addressFile = null;
      _birthFile = null;
      _fiscalPdf = null;
      _curpController.clear();
      _rfcController.clear();
    });
  }

  // ✅ NUEVO: Función para cerrar sesión con confirmación
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Cerrar sesión'),
          ],
        ),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Cerrar el diálogo

              try {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  // ✅ DESCOMENTA ESTO para ir directo al Login al cerrar sesión:
                  // Navigator.of(context).pushAndRemoveUntil(
                  //   MaterialPageRoute(builder: (context) => const LoginScreen()), // <-- Cambia 'LoginScreen' por tu pantalla real
                  //   (route) => false,
                  // );

                  // Mientras tanto, mostramos este mensaje:
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sesión cerrada correctamente'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(File? current, Function(File) onPicked) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      onPicked(File(pickedFile.path));
      setState(() {});
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _fiscalPdf = File(result.files.single.path!));
    }
  }

  Future<void> _uploadDocuments() async {
    if (_idImage == null || _selfieImage == null || _fiscalPdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debes subir INE, Selfie y Constancia Fiscal')),
      );
      return;
    }

    if (_curpController.text.length < 18 || _rfcController.text.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Verifica que CURP (18 chars) y RFC (12+ chars) estén correctos')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final storageRef = FirebaseStorage.instance.ref().child('verifications/${user.uid}');

      final idUrl = await (await storageRef.child('id.jpg').putFile(_idImage!)).ref.getDownloadURL();
      final selfieUrl = await (await storageRef.child('selfie.jpg').putFile(_selfieImage!)).ref.getDownloadURL();

      String? addressUrl;
      if (_addressFile != null) {
        addressUrl = await (await storageRef.child('address_proof.jpg').putFile(_addressFile!)).ref.getDownloadURL();
      }

      String? birthUrl;
      if (_birthFile != null) {
        birthUrl = await (await storageRef.child('birth_cert.jpg').putFile(_birthFile!)).ref.getDownloadURL();
      }

      final fiscalUrl = await (await storageRef.child('fiscal_const.pdf').putFile(_fiscalPdf!)).ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'idDocumentUrl': idUrl,
        'selfieUrl': selfieUrl,
        'addressProofUrl': addressUrl,
        'birthCertUrl': birthUrl,
        'fiscalConstUrl': fiscalUrl,
        'curp': _curpController.text.trim().toUpperCase(),
        'rfc': _rfcController.text.trim().toUpperCase(),
        'verificationStatus': 'pending',
        'documentsSubmittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // 1. Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Documentos enviados correctamente. Espera la revisión del admin.'),
          backgroundColor: Colors.green,
        ),
      );

      // 2. ✅ LIMPIAR EL FORMULARIO AUTOMÁTICAMENTE
      _clearForm();

      // Opcional: Regresar a la pantalla anterior después de 2 segundos
      // Future.delayed(const Duration(seconds: 2), () {
      //   if (mounted) Navigator.pop(context);
      // });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al subir: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación de Paseador'),
        // ✅ BOTÓN DE CERRAR SESIÓN AGREGADO AQUÍ
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _confirmLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Completa tu perfil para comenzar a trabajar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Todos los campos marcados con * son obligatorios',
                style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 32),

            _buildTextField(_curpController, 'CURP *', Icons.badge, maxLength: 18),
            const SizedBox(height: 16),
            _buildTextField(_rfcController, 'RFC *', Icons.numbers, maxLength: 13),
            const SizedBox(height: 32),

            const Text('Identidad Oficial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildImagePicker('INE / Pasaporte *', _idImage, () => _pickImage(_idImage, (f) => _idImage = f), Icons.credit_card),
            const SizedBox(height: 16),
            _buildImagePicker('Selfie Actual *', _selfieImage, () => _pickImage(_selfieImage, (f) => _selfieImage = f), Icons.camera_alt),

            const SizedBox(height: 32),

            const Text('Domicilio y Legal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildImagePicker('Comprobante de Domicilio', _addressFile, () => _pickImage(_addressFile, (f) => _addressFile = f), Icons.home),
            const SizedBox(height: 16),
            _buildImagePicker('Acta de Nacimiento', _birthFile, () => _pickImage(_birthFile, (f) => _birthFile = f), Icons.child_care),

            const SizedBox(height: 32),

            const Text('Situación Fiscal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickPdf,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(12),
                  color: _fiscalPdf != null ? Colors.orange.shade50 : Colors.white,
                ),
                child: _fiscalPdf != null
                    ? Row(children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Constancia cargada', style: TextStyle(color: Colors.grey[800])))
                ])
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.upload_file, color: Colors.orange, size: 32),
                  SizedBox(width: 8),
                  Text('Subir Constancia de Situación Fiscal (PDF) *')
                ]),
              ),
            ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadDocuments,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: _isUploading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enviar Documentación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
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
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildImagePicker(String label, File? file, VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange),
          borderRadius: BorderRadius.circular(12),
          color: file != null ? Colors.orange.shade50 : Colors.white,
        ),
        child: file != null
            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(file, fit: BoxFit.cover))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 32, color: Colors.orange),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12))
        ]),
      ),
    );
  }
}