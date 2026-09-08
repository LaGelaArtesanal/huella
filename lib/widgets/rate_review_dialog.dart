import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/review_service.dart';
import 'star_rating_widget.dart';

class RateReviewDialog extends StatefulWidget {
  final String walkId;
  final String reviewerId; // ID del dueño
  final String reviewedId; // ID del paseador
  final String reviewedName; // Nombre del paseador

  const RateReviewDialog({
    super.key,
    required this.walkId,
    required this.reviewerId,
    required this.reviewedId,
    required this.reviewedName,
  });

  @override
  State<RateReviewDialog> createState() => _RateReviewDialogState();
}

class _RateReviewDialogState extends State<RateReviewDialog> {
  final _commentController = TextEditingController();
  int _selectedRating = 5;
  double _selectedTip = 0; // ✅ Monto de la propina
  bool _isSubmitting = false;
  final _reviewService = ReviewService();

  // Opciones predefinidas de propina
  final List<double> _tipOptions = [10, 20, 50, 100];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView( // Scroll por si el teclado ocupa espacio
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pets, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                '¿Cómo fue el paseo con ${widget.reviewedName}?',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ⭐ Estrellas
              StarRatingWidget(
                rating: _selectedRating,
                size: 40,
                color: Colors.amber,
                onTap: () {
                  setState(() {
                    _selectedRating = _selectedRating == 5 ? 1 : _selectedRating + 1;
                  });
                },
              ),
              const SizedBox(height: 24),

              // 💬 Comentario
              TextField(
                controller: _commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Comentario (opcional)...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 24),

              // 💰 SECCIÓN DE PROPINA
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '¿Deseas dejar una propina?',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Botones de propina
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tipOptions.map((amount) {
                  final isSelected = _selectedTip == amount;
                  return ChoiceChip(
                    label: Text('\$$amount'),
                    selected: isSelected,
                    selectedColor: Colors.green,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedTip = selected ? amount : 0;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ✅ Botón de enviar (CORREGIDO: ${_selectedTip})
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                    _selectedTip > 0 ? 'Calificar y dejar \$${_selectedTip} de propina' : 'Enviar Calificación',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);

    try {
      await _reviewService.submitReview(
        walkId: widget.walkId,
        reviewerId: widget.reviewerId,
        reviewedId: widget.reviewedId,
        reviewedCollection: 'walker_profiles',
        rating: _selectedRating,
        comment: _commentController.text.trim(),
        tipAmount: _selectedTip,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // ✅ CORREGIDO: ${_selectedTip}
            content: Text(_selectedTip > 0 ? '¡Gracias! Propina de \$${_selectedTip} registrada.' : '¡Gracias por tu calificación! ⭐'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}