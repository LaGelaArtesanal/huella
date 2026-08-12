import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pet_model.dart';

class PaymentSummaryScreen extends StatefulWidget {
  final PetModel pet;
  final String ownerId;
  final String ownerName;
  final double ownerLat;
  final double ownerLng;
  final int durationMinutes;
  final double priceMultiplier;
  final bool isScheduled;
  final DateTime? scheduledDate;
  final TimeOfDay? scheduledTime;

  const PaymentSummaryScreen({
    super.key,
    required this.pet,
    required this.ownerId,
    required this.ownerName,
    required this.ownerLat,
    required this.ownerLng,
    required this.durationMinutes,
    required this.priceMultiplier,
    required this.isScheduled,
    this.scheduledDate,
    this.scheduledTime,
  });

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  bool _isProcessing = false;

  // CAMBIO CLAVE: Tarifa base fija del paseador
  static const double BASE_WALKER_PRICE = 100.0;

  // Cálculo correcto: Base * Multiplicador
  double get _finalPrice => BASE_WALKER_PRICE * widget.priceMultiplier;

  Future<void> _processPaymentAndCreateWalk() async {
    setState(() => _isProcessing = true);

    try {
      await Future.delayed(const Duration(seconds: 2));

      final walkData = {
        'ownerId': widget.ownerId,
        'ownerName': widget.ownerName,
        'petId': widget.pet.id,
        'petName': widget.pet.name,
        'status': 'paid',
        'durationMinutes': widget.durationMinutes,
        'priceMultiplier': widget.priceMultiplier,
        'amount': _finalPrice,
        'isImmediate': !widget.isScheduled,
        'createdAt': FieldValue.serverTimestamp(),
        'ownerLat': widget.ownerLat,
        'ownerLng': widget.ownerLng,
      };

      if (!widget.isScheduled && widget.scheduledDate != null && widget.scheduledTime != null) {
        final scheduledDateTime = DateTime(
          widget.scheduledDate!.year,
          widget.scheduledDate!.month,
          widget.scheduledDate!.day,
          widget.scheduledTime!.hour,
          widget.scheduledTime!.minute,
        );
        walkData['scheduledTime'] = Timestamp.fromDate(scheduledDateTime);
      } else {
        walkData['scheduledTime'] = Timestamp.now();
      }

      await FirebaseFirestore.instance.collection('walks').add(walkData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isScheduled ? '✅ ¡Paseo agendado y pagado!' : '✅ ¡Pago exitoso! Buscando paseador...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context);
      Navigator.pop(context);
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Text('Resumen y Pago', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(widget.isScheduled ? Icons.calendar_today : Icons.flash_on, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              widget.isScheduled ? 'Paseo Agendado' : 'Paseo Inmediato',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Duración: ${widget.durationMinutes} minutos', style: TextStyle(color: Colors.grey[700])),
                        if (widget.isScheduled && widget.scheduledDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Fecha: ${widget.scheduledDate!.day}/${widget.scheduledDate!.month} - ${widget.scheduledTime?.format(context)}',
                            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('Mascota Seleccionada', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: Colors.deepOrange, child: Icon(Icons.pets, color: Colors.white)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.pet.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('${widget.pet.breed}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text('Desglose de Precio', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        // TARIFA BASE CORREGIDA
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tarifa base del paseador'),
                              Text('\$${BASE_WALKER_PRICE.toStringAsFixed(2)}')
                            ]
                        ),

                        const SizedBox(height: 8),

                        // MULTIPLICADOR VISUALMENTE LIMPIO
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Ajuste por duración (${widget.durationMinutes} min)'),
                              Text(
                                  'x${widget.priceMultiplier} (${((widget.priceMultiplier * 100).round())}%)',
                                  style: TextStyle(color: Colors.grey[600])
                              )
                            ]
                        ),

                        const Divider(height: 24),

                        // TOTAL CORRECTO
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TOTAL A PAGAR', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                  '\$${_finalPrice.toStringAsFixed(2)} MXN',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 20)
                              )
                            ]
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: !_isProcessing ? _processPaymentAndCreateWalk : null,
                  icon: _isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock_outline),
                  label: Text(_isProcessing ? 'Procesando...' : 'Confirmar y Pagar', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}