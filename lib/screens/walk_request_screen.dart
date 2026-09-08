import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk_model.dart';
import '../models/pet_model.dart';
import '../models/walker_profile_model.dart';
import 'chat_screen.dart';

class WalkRequestScreen extends StatefulWidget {
  final PetModel pet;
  final WalkerProfileModel walker;
  final String ownerId;
  final double ownerLat;
  final double ownerLng;
  final String ownerName;

  const WalkRequestScreen({
    super.key,
    required this.pet,
    required this.walker,
    required this.ownerId,
    required this.ownerLat,
    required this.ownerLng,
    required this.ownerName,
  });

  @override
  State<WalkRequestScreen> createState() => _WalkRequestScreenState();
}

class _WalkRequestScreenState extends State<WalkRequestScreen> {
  bool _isProcessing = false;
  DateTime? _selectedDate;

  String _getChatId(String id1, String id2) {
    List<String> ids = [id1, id2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _requestAndPay() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una fecha y hora')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final finalPrice = widget.walker.pricePerWalk * widget.pet.getPriceMultiplier();

      final walkRef = FirebaseFirestore.instance.collection('walks').doc();
      final walk = WalkModel(
        id: walkRef.id,
        ownerId: widget.ownerId,
        walkerId: widget.walker.userId,
        petId: widget.pet.id,
        amount: finalPrice,
        scheduledTime: _selectedDate!,
        status: 'paid',
        createdAt: DateTime.now(),
      );

      await walkRef.set(walk.toMap());

      // ✅ Alimentar el mapa de calor de demanda (colección walk_requests_heatmap)
      // Usamos la ubicación del domicilio del dueño registrada en su perfil.
      try {
        final ownerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.ownerId)
            .get();
        if (ownerDoc.exists) {
          final data = ownerDoc.data()!;
          final lat = (data['homeLat'] ?? data['latitude'] ?? data['lat']);
          final lng = (data['homeLng'] ?? data['longitude'] ?? data['lng']);
          if (lat != null && lng != null) {
            await FirebaseFirestore.instance.collection('walk_requests_heatmap').add({
              'lat': (lat as num).toDouble(),
              'lng': (lng as num).toDouble(),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        print('⚠️ No se pudo registrar en el heatmap: $e');
      }

      if (!mounted) return;

      // CORRECCIÓN: Pasar otherUserId para que ChatScreen busque el nombre
      final chatId = _getChatId(widget.ownerId, widget.walker.userId);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            currentUserId: widget.ownerId,
            otherUserId: widget.walker.userId, // <-- CAMBIO CLAVE
            isWalker: false,
          ),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Pago exitoso. ¡Chat habilitado!')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalPrice = widget.walker.pricePerWalk * widget.pet.getPriceMultiplier();
    final adjustment = finalPrice - widget.walker.pricePerWalk;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('Solicitar Paseo', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.pets, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.pet.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          Text('${widget.pet.breed} • ${widget.pet.getSizeLabel()}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('Fecha y Hora del Paseo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDateTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: Colors.orange.shade300), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.orange),
                    const SizedBox(width: 12),
                    Text(_selectedDate == null ? 'Toca para seleccionar' : '${_selectedDate!.day}/${_selectedDate!.month} - ${_selectedDate!.hour}:${_selectedDate!.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.poppins(fontSize: 16)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('Resumen de Pago', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Tarifa base paseador', style: TextStyle(color: Colors.grey[600]))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('\$${widget.walker.pricePerWalk.toStringAsFixed(0)}', style: GoogleFonts.poppins())]),

            const SizedBox(height: 8),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Ajuste por tamaño (${widget.pet.getSizeLabel()})', style: TextStyle(color: Colors.orange.shade700))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('+ \$${adjustment.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: Colors.orange.shade700))]),

            const Divider(height: 32),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('TOTAL A PAGAR', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('\$${finalPrice.toStringAsFixed(0)} MXN', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.deepOrange))]),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isProcessing || _selectedDate == null ? null : _requestAndPay,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Pagar y Abrir Chat', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Al pagar, se creará el paseo y podrás chatear directamente con el paseador.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}