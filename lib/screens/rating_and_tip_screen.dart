import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingAndTipScreen extends StatefulWidget {
  final String walkId;
  final String walkerId;
  final String ownerId;
  final double finalAmount;
  final String petName;

  const RatingAndTipScreen({
    super.key,
    required this.walkId,
    required this.walkerId,
    required this.ownerId,
    required this.finalAmount,
    required this.petName,
  });

  @override
  State<RatingAndTipScreen> createState() => _RatingAndTipScreenState();
}

class _RatingAndTipScreenState extends State<RatingAndTipScreen> {
  int _rating = 0;
  double _tipAmount = 0.0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  final List<double> _tipOptions = [0.0, 20.0, 50.0, 100.0];

  Future<void> _submitRatingAndTip() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor califica al paseador'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Guardar calificación y comentario
      await FirebaseFirestore.instance.collection('ratings').add({
        'walkId': widget.walkId,
        'walkerId': widget.walkerId,
        'ownerId': widget.ownerId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Actualizar promedio de calificaciones del paseador
      final walkerRatings = await FirebaseFirestore.instance
          .collection('ratings')
          .where('walkerId', isEqualTo: widget.walkerId)
          .get();

      double totalRating = 0;
      for (var doc in walkerRatings.docs) {
        totalRating += (doc.data()['rating'] as int).toDouble();
      }
      double averageRating = walkerRatings.docs.isNotEmpty ? totalRating / walkerRatings.docs.length : 0;

      await FirebaseFirestore.instance.collection('users').doc(widget.walkerId).update({
        'averageRating': averageRating,
        'totalRatings': FieldValue.increment(1),
      });

      // 3. Actualizar el paseo con la propina (SOLO la propina, sin comisión)
      await FirebaseFirestore.instance.collection('walks').doc(widget.walkId).update({
        'tipAmount': _tipAmount,
        'rated': true,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      // 4. Si hay propina, actualizar la billetera del paseador
      if (_tipAmount > 0) {
        final walletRef = FirebaseFirestore.instance.collection('wallets').doc(widget.walkerId);
        final walletDoc = await walletRef.get();

        if (walletDoc.exists) {
          await walletRef.update({
            'availableBalance': FieldValue.increment(_tipAmount),
            'totalTips': FieldValue.increment(_tipAmount),
            'transactions': FieldValue.arrayUnion([
              {
                'walkId': widget.walkId,
                'type': 'tip',
                'amount': _tipAmount,
                'description': 'Propina por paseo #${widget.walkId.substring(0, 6)}',
                'status': 'available',
                'createdAt': FieldValue.serverTimestamp(),
              }
            ]),
          });
        } else {
          await walletRef.set({
            'availableBalance': _tipAmount,
            'pendingBalance': 0.0,
            'totalTips': _tipAmount,
            'transactions': [
              {
                'walkId': widget.walkId,
                'type': 'tip',
                'amount': _tipAmount,
                'description': 'Propina por paseo #${widget.walkId.substring(0, 6)}',
                'status': 'available',
                'createdAt': FieldValue.serverTimestamp(),
              }
            ],
          });
        }
      }

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Gracias por tu calificación!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('¿Cómo fue el paseo?', style: GoogleFonts.poppins(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Mascota
            CircleAvatar(
              backgroundColor: Colors.green.shade100,
              radius: 50,
              child: Icon(Icons.pets, size: 50, color: Colors.green.shade700),
            ),
            const SizedBox(height: 16),
            Text(
              'Paseo de ${widget.petName}',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Total del servicio: \$${widget.finalAmount.toStringAsFixed(2)} MXN',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Calificación con estrellas
            Text('Califica al paseador', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                  onPressed: () => setState(() => _rating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Propina
            Text('¿Quieres dejar una propina?', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('100% para el paseador', style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _tipOptions.map((tip) {
                final isSelected = _tipAmount == tip;
                return ChoiceChip(
                  label: Text(tip == 0 ? 'Sin propina' : '\$${tip.toStringAsFixed(0)}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _tipAmount = tip);
                  },
                  selectedColor: Colors.green,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Comentario opcional
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Cuéntanos cómo fue tu experiencia...',
              ),
            ),
            const SizedBox(height: 32),

            // Botón enviar
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRatingAndTip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Enviar Calificación', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}