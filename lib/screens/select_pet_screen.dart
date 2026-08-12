import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pet_model.dart';
// Importa tu pantalla de resumen de pago (ajusta el nombre si es diferente)
import 'payment_summary_screen.dart';

class SelectPetScreen extends StatefulWidget {
  final String ownerId;
  final String ownerName;
  final double ownerLat;
  final double ownerLng;

  // Parámetros opcionales provenientes de RequestWalkScreen
  final int? durationMinutes;
  final double? priceMultiplier;
  final bool? isScheduled;
  final DateTime? scheduledDate;
  final TimeOfDay? scheduledTime;

  const SelectPetScreen({
    super.key,
    required this.ownerId,
    required this.ownerName,
    required this.ownerLat,
    required this.ownerLng,
    this.durationMinutes,
    this.priceMultiplier,
    this.isScheduled,
    this.scheduledDate,
    this.scheduledTime,
  });

  @override
  State<SelectPetScreen> createState() => _SelectPetScreenState();
}

class _SelectPetScreenState extends State<SelectPetScreen> {
  List<PetModel> _pets = [];
  PetModel? _selectedPet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pets')
          .where('ownerId', isEqualTo: widget.ownerId)
          .get();

      if (mounted) {
        setState(() {
          _pets = snapshot.docs.map((doc) => PetModel.fromMap(doc.data(), doc.id)).toList();
          if (_pets.isNotEmpty) _selectedPet = _pets.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error cargando mascotas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Text('Seleccionar Mascota', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Quién irá de paseo?', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (_pets.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.pets_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('No tienes mascotas registradas', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pets.length,
                      itemBuilder: (context, index) {
                        final pet = _pets[index];
                        final isSelected = _selectedPet?.id == pet.id;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedPet = pet),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.orange.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? Colors.deepOrange : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isSelected ? Colors.deepOrange : Colors.grey.shade200,
                                  child: Icon(Icons.pets, color: isSelected ? Colors.white : Colors.grey.shade600),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(pet.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('${pet.breed}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                    ],
                                  ),
                                ),
                                if (isSelected) Icon(Icons.check_circle, color: Colors.deepOrange, size: 28),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Botón inferior fijo para continuar al pago
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _selectedPet != null ? () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentSummaryScreen(
                      pet: _selectedPet!,
                      ownerId: widget.ownerId,
                      ownerName: widget.ownerName,
                      ownerLat: widget.ownerLat,
                      ownerLng: widget.ownerLng,
                      durationMinutes: widget.durationMinutes ?? 50,
                      priceMultiplier: widget.priceMultiplier ?? 1.0,
                      isScheduled: widget.isScheduled ?? false,
                      scheduledDate: widget.scheduledDate,
                      scheduledTime: widget.scheduledTime,
                    )));
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Continuar al Pago', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}