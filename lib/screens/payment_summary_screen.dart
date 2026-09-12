import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pet_model.dart';
import '../config/pricing_config.dart';
import '../services/payment_service.dart';
import 'payment_success_screen.dart'; // ✅ Importación correcta

class PaymentSummaryScreen extends StatefulWidget {
  final PetModel pet;
  final String petSize;
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
    required this.petSize,
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
  final PaymentService _payments = PaymentService();
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

  // ==========================================================
  // FLUJO DE PAGO
  // ==========================================================

  Future<void> _onPayTapped() async {
    if (_payments.canUseCard) {
      _showPaymentMethodDialog();
    } else {
      await _payWithCash();
    }
  }

  void _showPaymentMethodDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Método de pago', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PaymentOptionTile(
              icon: Icons.credit_card,
              iconColor: Colors.blue,
              title: 'Tarjeta',
              subtitle: 'Pago seguro con tarjeta de crédito o débito (Stripe)',
              onTap: () {
                Navigator.pop(ctx);
                _payWithCard();
              },
            ),
            const SizedBox(height: 8),
            _PaymentOptionTile(
              icon: Icons.payments_outlined,
              iconColor: Colors.green,
              title: 'Efectivo',
              subtitle: 'Pagas al paseador en persona al finalizar el paseo',
              onTap: () {
                Navigator.pop(ctx);
                _payWithCash();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<DocumentReference> _createWalkDoc({
    required String status,
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    DateTime finalScheduledTime = widget.isScheduled && widget.scheduledDate != null && widget.scheduledTime != null
        ? DateTime(widget.scheduledDate!.year, widget.scheduledDate!.month, widget.scheduledDate!.day, widget.scheduledTime!.hour, widget.scheduledTime!.minute)
        : DateTime.now();

    final ref = await FirebaseFirestore.instance.collection('walks').add({
      'ownerId': widget.ownerId,
      'ownerName': widget.ownerName,
      'ownerLat': widget.ownerLat,
      'ownerLng': widget.ownerLng,
      'petId': widget.pet.id,
      'petName': widget.pet.name,
      'petSize': widget.petSize,
      'durationMinutes': widget.durationMinutes,
      'basePrice': widget.basePrice,
      'priceMultiplier': widget.priceMultiplier,
      'sizeMultiplier': _sizeMultiplier,
      'finalAmount': _finalAmount,
      'isScheduled': widget.isScheduled,
      'scheduledTime': Timestamp.fromDate(finalScheduledTime),
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await FirebaseFirestore.instance.collection('walk_requests_heatmap').add({
        'lat': widget.ownerLat,
        'lng': widget.ownerLng,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ No se pudo registrar en el heatmap: $e');
    }

    return ref;
  }

  Future<void> _markWalkPaymentCancelled(String walkId) async {
    try {
      await FirebaseFirestore.instance.collection('walks').doc(walkId).update({
        'status': 'payment_cancelled',
        'paymentStatus': 'failed',
        'paymentCancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ No se pudo marcar el paseo como cancelado: $e');
    }
  }

  /// 💳 Tarjeta: crear paseo "esperando pago" → PaymentIntent → hoja de pago.
  Future<void> _payWithCard() async {
    setState(() => _isProcessing = true);
    String? walkId;

    try {
      // 1. Crear el paseo en estado "esperando pago".
      final walkRef = await _createWalkDoc(
        status: 'pending_payment',
        paymentMethod: 'card',
        paymentStatus: 'pending',
      );
      walkId = walkRef.id;

      // 2. Crear el PaymentIntent en el backend.
      final intent = await _payments.createPaymentIntent(
        amount: _finalAmount,
        currency: 'mxn',
        walkId: walkId,
      );

      // 3. Abrir la hoja de pago nativa de Stripe.
      final outcome = await _payments.presentPaymentSheet(
        clientSecret: intent['clientSecret']!,
        paymentIntentId: intent['paymentIntentId']!,
      );

      if (!mounted) return;

      // 4. Actualizar el paseo y navegar según el resultado.
      if (outcome.success) {
        await FirebaseFirestore.instance.collection('walks').doc(walkId).update({
          'status': 'pending',
          'paymentStatus': 'paid',
          'stripePaymentIntentId': outcome.paymentIntentId,
          'paidAt': FieldValue.serverTimestamp(),
        });

        // ✅ CORREGIDO: walkId! porque aquí ya sabemos que tiene valor
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              amount: _finalAmount,
              currency: 'mxn',
              walkId: walkId!,
            ),
          ),
        );
      } else if (outcome.cancelled) {
        await _markWalkPaymentCancelled(walkId);
        setState(() => _isProcessing = false);
        _snack('Pago cancelado. Puedes intentar de nuevo cuando quieras.', isWarning: true);
      } else {
        await _markWalkPaymentCancelled(walkId);
        setState(() => _isProcessing = false);
        _snack(outcome.errorMessage ?? 'Error con el pago. Inténtalo de nuevo.', isError: true);
      }
    } catch (e) {
      print('❌ Error en el flujo de pago con tarjeta: $e');
      if (walkId != null) await _markWalkPaymentCancelled(walkId);
      if (mounted) {
        setState(() => _isProcessing = false);
        _snack('No se pudo procesar el pago. Inténtalo de nuevo.', isError: true);
      }
    }
  }

  /// 💵 Efectivo: crear el paseo directamente pendiente.
  Future<void> _payWithCash() async {
    setState(() => _isProcessing = true);
    try {
      final walkRef = await _createWalkDoc(
        status: 'pending',
        paymentMethod: 'cash',
        paymentStatus: 'unpaid',
      );

      if (mounted) {
        // ✅ CORREGIDO: walkRef.id es siempre un String seguro
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              amount: _finalAmount,
              currency: 'mxn',
              walkId: walkRef.id,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error al crear paseo (efectivo): $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _snack('Error: $e', isError: true);
      }
    }
  }

  void _snack(String message, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    final color = isError ? Colors.red : (isWarning ? Colors.orange : Colors.green);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Text('Resumen del Pago', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _onPayTapped,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isProcessing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Pagar y Solicitar Paseo', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (_payments.canUseCard)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock, size: 14, color: Colors.grey),
                    SizedBox(width: 6),
                    Text('Pago protegido por Stripe', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                )
              else ...[
                const SizedBox(height: 12),
                Text(
                  '💳 El pago con tarjeta solo está disponible en la app móvil. En esta versión web se registra el paseo para pago en efectivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
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

class _PaymentOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconColor.withOpacity(0.15),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}