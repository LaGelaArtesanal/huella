import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- AGREGADO PARA VERIFICAR TOKENS
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'admin_dashboard_screen.dart';
import 'home_owner_screen.dart';
import 'walker_dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String role;
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController(); // <--- NUEVO CONTROLADOR
  final _authService = AuthService();
  bool _isLoading = false;
  String? _error;

  Future<void> _register() async {
    setState(() { _isLoading = true; _error = null; });

    // Validación local rápida
    if (_passwordController.text.length < 6) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'La contraseña debe tener al menos 6 caracteres.'; });
      return;
    }

    // ✅ LÓGICA DE VALIDACIÓN DE TOKEN ADMIN
    String finalRole = widget.role; // Por defecto es 'owner' o 'walker'

    if (_tokenController.text.trim().isNotEmpty) {
      try {
        final tokenDoc = await FirebaseFirestore.instance
            .collection('admin_tokens')
            .doc(_tokenController.text.trim().toUpperCase()) // Normalizamos a mayúsculas
            .get();

        if (tokenDoc.exists && tokenDoc.data()?['isActive'] == true) {
          finalRole = 'temp_admin'; // ¡Aquí está la magia!

          // Marcar token como usado inmediatamente para evitar reuso
          await tokenDoc.reference.update({
            'usedBy': _emailController.text.trim(),
            'isActive': false,
            'usedAt': FieldValue.serverTimestamp(),
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = 'El código de administrador no es válido o ya fue usado.';
          });
          return; // Detenemos el registro si el token es inválido
        }
      } catch (e) {
        setState(() { _isLoading = false; _error = 'Error verificando código.'; });
        return;
      }
    }

    try {
      final user = await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        role: finalRole, // <--- PASAMOS EL ROL MODIFICADO (puede ser temp_admin)
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        Widget destination;
        if (user.role == 'admin' || user.role == 'temp_admin') {
          destination = AdminDashboardScreen();
        } else if (user.role == 'owner') {
          destination = HomeOwnerScreen(userId: user.uid, userName: user.name);
        } else {
          destination = WalkerDashboardScreen(walkerId: user.uid);
        }
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => destination), (route) => false);
      } else {
        setState(() => _error = 'Error al crear cuenta. Verifica los datos.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String message = 'Error al registrar.';
      if (e.code == 'weak-password') message = 'La contraseña es muy débil (mínimo 6 caracteres).';
      else if (e.code == 'email-already-in-use') message = 'Este correo ya está registrado.';
      else if (e.code == 'invalid-email') message = 'El formato del correo no es válido.';
      setState(() => _error = message);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Error de conexión.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE0B2), Color(0xFFFF9800)])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.role == 'owner' ? '¡Registra a tu perrito!' : '¡Únete como paseador!', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 32),
                _buildTextField(_nameController, 'Nombre completo', Icons.person),
                const SizedBox(height: 16),
                _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, 'Contraseña', Icons.lock, obscureText: true),

                // ✅ NUEVO CAMPO PARA EL TOKEN
                const SizedBox(height: 16),
                _buildTextField(_tokenController, 'Código Admin (Opcional)', Icons.vpn_key),

                if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Crear cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextField(controller: controller, obscureText: obscureText, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.orange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
    );
  }
}