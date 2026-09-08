import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/walker_profile_model.dart';
import '../services/walker_profile_service.dart';
import '../config/pricing_config.dart'; // ✅ Importar la config del admin

class EditWalkerProfileScreen extends StatefulWidget {
  final String userId;
  const EditWalkerProfileScreen({super.key, required this.userId});

  @override
  State<EditWalkerProfileScreen> createState() => _EditWalkerProfileScreenState();
}

class _EditWalkerProfileScreenState extends State<EditWalkerProfileScreen> {
  final _service = WalkerProfileService();

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  // ✅ ELIMINADO: _priceController ya no es necesario
  final _experienceController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSearching = false;
  bool _isAvailable = true;

  LatLng? _selectedLocation;
  double _radiusKm = 1.0;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  static const String _googleApiKey = 'AIzaSyAfeVLE4mIaK7ZGcNkmD2n_0awLDT8ZTMY';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await _service.getProfile(widget.userId);

    if (profile != null) {
      _nameController.text = profile.name ?? '';
      _bioController.text = profile.bio;
      // ✅ ELIMINADO: Ya no cargamos el precio en un controlador
      _experienceController.text = profile.experience;
      _isAvailable = profile.isAvailable;
      _radiusKm = profile.radiusKm;

      if (profile.latitude != null && profile.longitude != null) {
        _selectedLocation = LatLng(profile.latitude!, profile.longitude!);
        _updateMarkerAndCircle();
      } else {
        _selectedLocation = const LatLng(19.4326, -99.1332);
        _updateMarkerAndCircle();
      }
    } else {
      _selectedLocation = const LatLng(19.4326, -99.1332);
      _updateMarkerAndCircle();
    }

    if (mounted) setState(() => _isLoading = false);
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
        final location = data['results'][0]['geometry']['location'];
        final newLatLng = LatLng(location['lat'], location['lng']);

        setState(() => _selectedLocation = newLatLng);
        _updateMarkerAndCircle();

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLatLng, 16),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📍 Ubicación actualizada'), backgroundColor: Colors.green),
        );
      } else {
        final errorMsg = data['error_message'] ?? 'Dirección no encontrada. Intenta ser más específico.';
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

  void _updateMarkerAndCircle() {
    if (_selectedLocation == null) return;

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('walker_location'),
          position: _selectedLocation!,
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() => _selectedLocation = newPosition);
            _updateMarkerAndCircle();
          },
        ),
      );

      _circles.clear();
      _circles.add(
        Circle(
          circleId: const CircleId('coverage_radius'),
          center: _selectedLocation!,
          radius: _radiusKm * 1000,
          fillColor: Colors.orange.withOpacity(0.2),
          strokeColor: Colors.orange,
          strokeWidth: 2,
        ),
      );
    });
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor ingresa tu nombre')));
      return;
    }

    // ✅ ELIMINADA: Validación del precio, ya que es fijo y no lo edita el usuario

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona tu ubicación en el mapa')));
      return;
    }

    setState(() => _isSaving = true);

    final profile = WalkerProfileModel(
      userId: widget.userId,
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      pricePerWalk: PricingConfig.basePrice, // ✅ Siempre usa el precio base del admin
      experience: _experienceController.text.trim(),
      isAvailable: _isAvailable,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      radiusKm: _radiusKm,
    );

    final success = await _service.saveProfile(profile);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Perfil guardado exitosamente')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Error al guardar perfil')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('Mi Perfil de Paseador', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Información Pública', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Tu Nombre Completo',
                hintText: 'Ej: Carlos Pérez',
                prefixIcon: const Icon(Icons.person_outline, color: Colors.orange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Biografía / Descripción',
                hintText: 'Cuéntale a los dueños sobre ti...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ BLOQUEO: Tarifa Base de Solo Lectura (Reemplaza al TextField anterior)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.orange.shade700, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tarifa Base del Servicio',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${PricingConfig.basePrice.toStringAsFixed(2)} MXN',
                          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          '(Fijado por la administración)',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _experienceController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Experiencia',
                hintText: 'Ej: 3 años paseando perros, certificado en...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              ),
            ),

            const SizedBox(height: 24),
            Text('Zona de Cobertura', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Dirección o Punto de Referencia',
                hintText: 'Ej: Av. Reforma 222, Col. Juárez...',
                prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.orange),
                suffixIcon: IconButton(
                  icon: _isSearching
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search, color: Colors.orange),
                  onPressed: _isSearching ? null : _searchAddress,
                  tooltip: 'Buscar esta dirección en el mapa',
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              ),
            ),

            const SizedBox(height: 8),
            Text('Arrastra el marcador para ajustar tu punto base exacto:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 8),

            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation ?? const LatLng(19.4326, -99.1332),
                  zoom: 14,
                ),
                markers: _markers,
                circles: _circles,
                onTap: (latLng) {
                  setState(() => _selectedLocation = latLng);
                  _updateMarkerAndCircle();
                },
                onMapCreated: (controller) => _mapController = controller,
              ),
            ),

            const SizedBox(height: 16),
            Text('Radio de cobertura: ${_radiusKm.toStringAsFixed(1)} km',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            Slider(
              value: _radiusKm,
              min: 0.5,
              max: 5.0,
              divisions: 9,
              label: '${_radiusKm.toStringAsFixed(1)} km',
              onChanged: (value) {
                setState(() => _radiusKm = value);
                _updateMarkerAndCircle();
              },
              activeColor: Colors.orange,
            ),

            const SizedBox(height: 24),
            SwitchListTile(
              title: Text('Disponible para paseos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              subtitle: const Text('Desactiva si no estás aceptando nuevos paseos'),
              value: _isAvailable,
              onChanged: (val) => setState(() => _isAvailable = val),
              activeColor: Colors.orange,
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
    _bioController.dispose();
    // ✅ ELIMINADO: _priceController.dispose();
    _experienceController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}