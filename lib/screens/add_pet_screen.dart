import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pet_model.dart';
import '../services/pet_service.dart';

class AddPetScreen extends StatefulWidget {
  final String ownerId;
  const AddPetScreen({super.key, required this.ownerId});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _petService = PetService();

  String _selectedSize = 'medium';
  bool _isLoading = false;

  Future<void> _savePet() async {
    if (_nameController.text.trim().isEmpty ||
        _breedController.text.trim().isEmpty ||
        _ageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final pet = PetModel(
      id: '', // Se generará en Firestore
      ownerId: widget.ownerId,
      name: _nameController.text.trim(),
      breed: _breedController.text.trim(),
      size: _selectedSize,
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      createdAt: DateTime.now(),
    );

    final result = await _petService.addPet(pet);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null) {
      Navigator.pop(context, true); // Regresar y recargar lista
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar mascota')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('Nueva Mascota', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Información de tu perrito', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
            const SizedBox(height: 24),

            _buildTextField(_nameController, 'Nombre', Icons.pets),
            const SizedBox(height: 16),
            _buildTextField(_breedController, 'Raza', Icons.category),
            const SizedBox(height: 16),
            _buildTextField(_ageController, 'Edad (años)', Icons.cake, keyboardType: TextInputType.number),
            const SizedBox(height: 24),

            Text('Tamaño', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _SizeChip(label: 'Pequeño', value: 'small', selected: _selectedSize == 'small', onTap: () => setState(() => _selectedSize = 'small')),
                _SizeChip(label: 'Mediano', value: 'medium', selected: _selectedSize == 'medium', onTap: () => setState(() => _selectedSize = 'medium')),
                _SizeChip(label: 'Grande', value: 'large', selected: _selectedSize == 'large', onTap: () => setState(() => _selectedSize = 'large')),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePet,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Guardar Mascota', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _SizeChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.orange.shade200,
      checkmarkColor: Colors.orange.shade900,
      backgroundColor: Colors.grey.shade200,
    );
  }
}