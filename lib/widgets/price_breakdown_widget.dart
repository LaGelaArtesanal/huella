import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pet_model.dart';

class PriceBreakdownWidget extends StatelessWidget {
  final double basePrice; // Precio base del paseador
  final PetModel pet;     // Mascota del dueño

  const PriceBreakdownWidget({
    super.key,
    required this.basePrice,
    required this.pet
  });

  @override
  Widget build(BuildContext context) {
    final multiplier = pet.getPriceMultiplier();
    final adjustment = basePrice * (multiplier - 1);
    final totalPrice = basePrice * multiplier;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Desglose del Precio',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
          const SizedBox(height: 12),

          _PriceRow(label: 'Tarifa base del paseador', amount: basePrice),
          const SizedBox(height: 8),

          _PriceRow(
            label: 'Ajuste por tamaño (${pet.getSizeLabel()})',
            amount: adjustment,
            isAdjustment: true,
          ),

          const Divider(height: 24, thickness: 1),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL DEL PASEO',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('\$${totalPrice.toStringAsFixed(0)} MXN',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isAdjustment;

  const _PriceRow({
    required this.label,
    required this.amount,
    this.isAdjustment = false
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: isAdjustment ? Colors.orange.shade700 : Colors.grey[700],
                  fontSize: 14
              )),
        ),
        Text(
          isAdjustment && amount > 0
              ? '+\$${amount.toStringAsFixed(0)}'
              : '\$${amount.toStringAsFixed(0)}',
          style: TextStyle(
              color: isAdjustment ? Colors.orange.shade700 : Colors.black87,
              fontWeight: isAdjustment ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14
          ),
        ),
      ],
    );
  }
}