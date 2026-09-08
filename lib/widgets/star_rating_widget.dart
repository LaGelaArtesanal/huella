import 'package:flutter/material.dart';

class StarRatingWidget extends StatelessWidget {
  final int rating; // Calificación actual (0 a 5)
  final int size; // Tamaño de las estrellas
  final Color color; // Color de las estrellas
  final VoidCallback? onTap; // Opcional: si quieres que sean clickeables

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.size = 24,
    this.color = Colors.amber,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: onTap, // Permite hacer clic si se proporciona la función
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: color,
            size: size.toDouble(),
          ),
        );
      }),
    );
  }
}