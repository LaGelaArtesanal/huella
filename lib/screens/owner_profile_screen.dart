import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; // NUEVO: Import de Firestore
import '../models/user_model.dart';
import '../services/auth_service.dart';

class OwnerProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const OwnerProfileScreen({super.key, required this.userId, required this.userName});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _referenceController = TextEditingController(); // Controlador para referencia

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSearching = false;

  LatLng? _homeLocation;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  static const String _googleApiKey = 'AIzaSyAfeVLE4mIaK7ZGcNkmD2n_0awLDT8ZTMY';

  @override
  void initState() {
    super.initState();
    _loadProfileFromFirestore(); // Cargar datos reales al iniciar
  }

  // NUEVO: Cargar perfil desde Firestore
  Future<void> _loadProfileFromFirestore() async {
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _nameController.text = data['name'] ?? widget.userName;
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _referenceController.text = data['locationReference'] ?? ''; // Cargar referencia

        // Cargar ubicación si existe
        if (data['homeLat'] != null && data['homeLng'] != null) {
          _homeLocation = LatLng(data['homeLat'], data['homeLng']);
        } else {
          _homeLocation = const LatLng(19.4326, -99.1332);
        }
      } else {
        // Si no existe documento, usar valores por defecto
        _nameController.text = widget.userName;
        _homeLocation = const LatLng(19.4326, -99.1332);
      }

      _updateMarker();
    } catch (e) {
      print('Error cargando perfil: $e');
      // En caso de error, cargar valores básicos
      _nameController.text = widget.userName;
      _homeLocation = const LatLng(19.4326, -99.1332);
      _updateMarker();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateMarker() {
    if (_homeLocation == null) return;
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('home_location'),
          position: _homeLocation!,
          draggable: true,
          onDragEnd: (newPos) {
            setState(() => _homeLocation = newPos);
            _updateMarker();
          },
        ),
      );
    });
  }

  Future<void> _searchAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&components=country:MX&key=$_googleApiKey'
      );

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final loc = data['results'][0]['geometry']['location'];
        final newLatLng = LatLng(loc['lat'], loc['lng']);

        setState(() => _homeLocation = newLatLng);
        _updateMarker();
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 16));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📍 Ubicación actualizada'), backgroundColor: Colors.green),
        );
      } else {
        final errorMsg = data['error_message'] ?? 'Dirección no encontrada.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ $errorMsg'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ACTUALIZADO: Guardar en Firestore
  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }
    if (_homeLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona tu ubicación en el mapa')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Guardar/Actualizar documento en Firestore
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'locationReference': _referenceController.text.trim(), // <-- GUARDAR REFERENCIA
        'homeLat': _homeLocation!.latitude,
        'homeLng': _homeLocation!.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge:true evita borrar otros campos como 'role', 'email', etc.

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Perfil guardado en Firestore')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('Mi Perfil de Dueño', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datos Personales', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: const Icon(Icons.person_outline, color: Colors.orange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Teléfono de Contacto',
                prefixIcon: const Icon(Icons.phone_outlined, color: Colors.orange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              ),
            ),

            const SizedBox(height: 24),
            Text('Dirección de Recogida', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Calle, Número y Colonia',
                hintText: 'Ej: Av. Insurgentes Sur 1234, Col. Del Valle',
                prefixIcon: const Icon(Icons.home_outlined, color: Colors.orange),
                suffixIcon: IconButton(
                  icon: _isSearching
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search, color: Colors.orange),
                  onPressed: _isSearching ? null : _searchAddress,
                  tooltip: 'Buscar dirección',
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              ),
            ),

            const SizedBox(height: 16),

            // Campo de Referencia
            TextField(
              controller: _referenceController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Referencia de Ubicación (Opcional)',
                hintText: 'Ej: Casa color azul, portón negro, Depto 3B...',
                prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.orange),
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              ),
            ),

            const SizedBox(height: 8),
            Text('Arrastra el marcador para marcar tu domicilio exacto:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 8),

            Container(
              height: 300,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade300)),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _homeLocation ?? const LatLng(19.4326, -99.1332), zoom: 14),
                markers: _markers,
                onTap: (latLng) {
                  setState(() => _homeLocation = latLng);
                  _updateMarker();
                },
                onMapCreated: (controller) => _mapController = controller,
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Guardar Perfil', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _referenceController.dispose();
    super.dispose();
  }
}