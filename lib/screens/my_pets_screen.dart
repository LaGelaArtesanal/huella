import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pet_model.dart';
import '../services/pet_service.dart';
import 'add_pet_screen.dart';

class MyPetsScreen extends StatefulWidget {
  final String ownerId;
  const MyPetsScreen({super.key, required this.ownerId});

  @override
  State<MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends State<MyPetsScreen> {
  final _petService = PetService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('Mis Mascotas', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddPetScreen(ownerId: widget.ownerId)),
              );
              if (result == true) setState(() {}); // Recargar lista
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PetModel>>(
        stream: _petService.getPetsByOwner(widget.ownerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 80, color: Colors.orange.shade200),
                  const SizedBox(height: 16),
                  Text('No tienes mascotas registradas',
                      style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddPetScreen(ownerId: widget.ownerId)),
                      );
                      if (result == true) setState(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar mi primera mascota'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ],
              ),
            );
          }

          final pets = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final pet = pets[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Icon(Icons.pets, color: Colors.orange.shade700, size: 30),
                  ),
                  title: Text(pet.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${pet.breed} • ${pet.age} años', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getSizeColor(pet.size),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_getSizeLabel(pet.size),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context, pet),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getSizeColor(String size) {
    switch (size) {
      case 'small': return Colors.green;
      case 'large': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _getSizeLabel(String size) {
    switch (size) {
      case 'small': return 'Pequeño';
      case 'large': return 'Grande';
      default: return 'Mediano';
    }
  }

  void _confirmDelete(BuildContext context, PetModel pet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mascota'),
        content: Text('¿Estás seguro de que quieres eliminar a ${pet.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await _petService.deletePet(pet.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}