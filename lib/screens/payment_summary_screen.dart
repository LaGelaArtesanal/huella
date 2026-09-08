import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pet_model.dart';
import '../config/pricing_config.dart';

class PaymentSummaryScreen extends StatefulWidget {
  final PetModel pet;
  final String petSize; // ✅ NUEVO
  final String ownerId;
  final String ownerName;
  final double ownerLat;
  final double ownerLng;
  final int durationMinutes;
  final double priceMultiplier;
  final double basePrice;
  final bool isScheduled;
  final DateTime? scheduledDate;
  final TimeOfDay? scheduledTime;

  const PaymentSummaryScreen({
    super.key,
    required this.pet,
    required this.petSize, // ✅ NUEVO
    required this.ownerId,
    required this.ownerName,
    required this.ownerLat,
    required this.ownerLng,
    required this.durationMinutes,
    required this.priceMultiplier,
    required this.basePrice,
    required this.isScheduled,
    this.scheduledDate,
    this.scheduledTime,
  });

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  bool _isProcessing = false;

  double get _sizeMultiplier => PricingConfig.getSizeMultiplier(widget.petSize);

  double get _finalAmount {
    return PricingConfig.calculateFinalPrice(
      durationMultiplier: widget.priceMultiplier,
      size: widget.petSize,
    );
  }

  String _getSizeLabel(String? size) {
    final s = size?.toLowerCase().trim() ?? '';
    if (s == 'pequeño' || s == 'small' || s == 'chico') return 'Pequeño';
    if (s == 'mediano' || s == 'medium' || s == 'medio') return 'Mediano';
    return 'Grande';
  }

  Future<void> _confirmAndCreateWalk() async {
    setState(() => _isProcessing = true);
    try {
      DateTime finalScheduledTime = widget.isScheduled && widget.scheduledDate != null && widget.scheduledTime != null
          ? DateTime(widget.scheduledDate!.year, widget.scheduledDate!.month, widget.scheduledDate!.day, widget.scheduledTime!.hour, widget.scheduledTime!.minute)
          : DateTime.now();

      await FirebaseFirestore.instance.collection('walks').add({
        'ownerId': widget.ownerId,
        'ownerName': widget.ownerName,
        'ownerLat': widget.ownerLat,
        'ownerLng': widget.ownerLng,
        'petId': widget.pet.id,
        'petName': widget.pet.name,
        'petSize': widget.petSize, // ✅ Guardamos el tamaño
        'durationMinutes': widget.durationMinutes,
        'basePrice': widget.basePrice,
        'priceMultiplier': widget.priceMultiplier,
        'sizeMultiplier': _sizeMultiplier, // ✅ Guardamos el multiplicador de tamaño
        'finalAmount': _finalAmount,       // ✅ Guardamos el monto final calculado
        'isScheduled': widget.isScheduled,
        'scheduledTime': Timestamp.fromDate(finalScheduledTime),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ Alimentar el mapa de calor de demanda (colección walk_requests_heatmap)
      // Sin este registro, el heatmap del paseador no tenía datos que mostrar.
      try {
        await FirebaseFirestore.instance.collection('walk_requests_heatmap').add({
          'lat': widget.ownerLat,
          'lng': widget.ownerLng,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('⚠️ No se pudo registrar en el heatmap: $e');
      }

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ ¡Paseo solicitado con éxito! Buscando paseador...'), backgroundColor: Colors.green));
      }
    } catch (e) {
      print('Error al crear paseo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ resizeToAvoidBottomInset: false evita que el teclado o la barra de navegación empujen el contenido y causen overflow
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Text('Resumen del Pago', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // ✅ CORRECCIÓN 1: Reducimos el padding inferior de 24 a 16 para ganar esos 8 píxeles
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detalles del Servicio', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.deepOrange, child: const Icon(Icons.pets, color: Colors.white)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.pet.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${widget.pet.breed} • ${_getSizeLabel(widget.petSize)} • ${widget.durationMinutes} min', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Desglose de Tarifas', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(12), color: Colors.blue.shade50),
                child: Column(
                  children: [
                    _buildPriceRow('Precio Base del Servicio', '\$${widget.basePrice.toStringAsFixed(2)}', isInfo: true),
                    const Divider(height: 24),
                    _buildPriceRow('Ajuste por duración (${widget.durationMinutes} min)', '${widget.priceMultiplier.toStringAsFixed(2)}x', isMultiplier: true),
                    const Divider(height: 24),
                    _buildPriceRow('Ajuste por tamaño (${_getSizeLabel(widget.petSize)})', '${_sizeMultiplier.toStringAsFixed(2)}x', isMultiplier: true),
                    const Divider(height: 24),
                    _buildPriceRow('TOTAL A PAGAR', '\$${_finalAmount.toStringAsFixed(2)}', isBold: true, isTotal: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Nota: El precio base es fijado por la administración.', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic), textAlign: TextAlign.center),

              // ✅ CORRECCIÓN 2: Reducimos el espacio antes del botón de 32 a 24
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmAndCreateWalk,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isProcessing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Confirmar y Solicitar Paseo', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount, {bool isBold = false, bool isTotal = false, bool isInfo = false, bool isMultiplier = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isInfo ? Colors.blue.shade800 : Colors.black87)),
          Text(amount, style: TextStyle(fontSize: isTotal ? 20 : 14, fontWeight: isBold ? FontWeight.bold : (isMultiplier ? FontWeight.w600 : FontWeight.normal), color: isTotal ? Colors.green.shade700 : (isMultiplier ? Colors.orange.shade800 : Colors.black87))),
        ],
      ),
    );
  }
}