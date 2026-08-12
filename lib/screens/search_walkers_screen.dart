import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

// Imports existentes
import '../models/walker_profile_model.dart';
import '../models/pet_model.dart';
import '../services/walker_profile_service.dart';
import '../widgets/price_breakdown_widget.dart';
import 'walk_request_screen.dart';

class SearchWalkersScreen extends StatefulWidget {
  final PetModel selectedPet;
  final double ownerLat;
  final double ownerLng;
  final String ownerId;
  final String ownerName;

  const SearchWalkersScreen({
    super.key,
    required this.selectedPet,
    required this.ownerLat,
    required this.ownerLng,
    required this.ownerId,
    required this.ownerName,
  });

  @override
  State<SearchWalkersScreen> createState() => _SearchWalkersScreenState();
}

class _SearchWalkersScreenState extends State<SearchWalkersScreen> {
  final _service = WalkerProfileService();

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('Buscar Paseadores', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<List<WalkerProfileModel>>(
        stream: _service.getAvailableWalkers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No hay paseadores disponibles cerca',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }

          final walkers = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: walkers.length,
            itemBuilder: (context, index) {
              final walker = walkers[index];

              double? distanceKm;
              if (walker.latitude != null && walker.longitude != null) {
                distanceKm = _calculateDistance(
                    widget.ownerLat, widget.ownerLng,
                    walker.latitude!, walker.longitude!
                );
              }

              final finalPrice = walker.pricePerWalk * widget.selectedPet.getPriceMultiplier();

              // Lógica robusta para obtener el nombre real
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(walker.userId).get(),
                builder: (context, userSnapshot) {
                  String displayName = 'Paseador';

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    displayName = walker.name?.isNotEmpty == true
                        ? walker.name!
                        : (userData?['name'] ?? 'Paseador ${walker.userId.substring(0, 6)}');
                  } else if (walker.name?.isNotEmpty == true) {
                    displayName = walker.name!;
                  } else {
                    displayName = 'Paseador ${walker.userId.substring(0, 6)}';
                  }

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Icon(Icons.directions_walk, color: Colors.blue.shade700),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(displayName,
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (distanceKm != null)
                                      Text('A ${distanceKm.toStringAsFixed(1)} km de ti',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Verificado', style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          if (walker.bio.isNotEmpty)
                            Text(walker.bio, style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (walker.experience.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('🎓 ${walker.experience}', style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],

                          const SizedBox(height: 16),

                          PriceBreakdownWidget(
                            basePrice: walker.pricePerWalk,
                            pet: widget.selectedPet,
                          ),

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WalkRequestScreen(
                                      pet: widget.selectedPet,
                                      walker: walker,
                                      ownerId: widget.ownerId,
                                      ownerLat: widget.ownerLat,
                                      ownerLng: widget.ownerLng,
                                      // Aseguramos pasar el ID del dueño para que WalkRequestScreen pueda usarlo después
                                      ownerName: widget.ownerName,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Solicitar Paseo (\$${finalPrice.toStringAsFixed(0)})',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}