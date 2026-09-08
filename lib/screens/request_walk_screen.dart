import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/pricing_config.dart'; // ✅ Importamos la config
import 'select_pet_screen.dart';

class RequestWalkScreen extends StatefulWidget {
  final String ownerId;
  final String ownerName;
  final double ownerLat;
  final double ownerLng;

  const RequestWalkScreen({
    super.key,
    required this.ownerId,
    required this.ownerName,
    required this.ownerLat,
    required this.ownerLng,
  });

  @override
  State<RequestWalkScreen> createState() => _RequestWalkScreenState();
}

class _RequestWalkScreenState extends State<RequestWalkScreen> {
  int? _selectedDuration;
  double _selectedMultiplier = 1.0;

  bool _isScheduled = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  void _selectDuration(int minutes, double multiplier) {
    setState(() {
      _selectedDuration = minutes;
      _selectedMultiplier = multiplier;
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(date),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDate = DateTime(date.year, date.month, date.day);
          _selectedTime = time;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos los precios reales basados en la configuración
    final price30 = PricingConfig.calculateFinalPrice(durationMultiplier: PricingConfig.multiplier30Min);
    final price50 = PricingConfig.calculateFinalPrice(durationMultiplier: PricingConfig.multiplier50Min);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Configurar Paseo', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Cuándo necesitas el paseo?', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _isScheduled = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isScheduled ? Colors.deepOrange : Colors.grey.shade200,
                      foregroundColor: !_isScheduled ? Colors.white : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Solicitar Ahora', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _isScheduled = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScheduled ? Colors.blue : Colors.grey.shade200,
                      foregroundColor: _isScheduled ? Colors.white : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Agendar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isScheduled) ...[
              GestureDetector(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha y Hora', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDate == null ? 'Tocar para seleccionar' : '${_selectedDate!.day}/${_selectedDate!.month} - ${_selectedTime?.format(context) ?? '--:--'}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.blue.shade400, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.flash_on, color: Colors.deepOrange, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text('Buscaremos un paseador disponible cerca de ti inmediatamente.', style: TextStyle(color: Colors.deepOrange.shade900, fontSize: 14)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            Text('Duración del Paseo', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ✅ Opción 30 Minutos con PRECIO REAL CALCULADO
            _buildDurationCard(
              minutes: 30,
              multiplier: PricingConfig.multiplier30Min,
              displayPrice: price30, // <-- Mostramos el precio real ($70)
              isSelected: _selectedDuration == 30,
              onTap: () => _selectDuration(30, PricingConfig.multiplier30Min),
              subtitle: 'Ideal para caminatas rápidas',
            ),

            const SizedBox(height: 16),

            // ✅ Opción 50 Minutos con PRECIO REAL CALCULADO
            _buildDurationCard(
              minutes: 50,
              multiplier: PricingConfig.multiplier50Min,
              displayPrice: price50, // <-- Mostramos el precio real ($100)
              isSelected: _selectedDuration == 50,
              onTap: () => _selectDuration(50, PricingConfig.multiplier50Min),
              subtitle: 'Paseo completo estándar',
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (_selectedDuration == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor selecciona la duración')));
                    return;
                  }
                  if (_isScheduled && (_selectedDate == null || _selectedTime == null)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor selecciona fecha y hora')));
                    return;
                  }

                  Navigator.push(context, MaterialPageRoute(builder: (_) => SelectPetScreen(
                    ownerId: widget.ownerId,
                    ownerName: widget.ownerName,
                    ownerLat: widget.ownerLat,
                    ownerLng: widget.ownerLng,
                    durationMinutes: _selectedDuration,
                    priceMultiplier: _selectedMultiplier,
                    basePrice: PricingConfig.basePrice, // ✅ Enviamos el precio base
                    isScheduled: _isScheduled,
                    scheduledDate: _selectedDate,
                    scheduledTime: _selectedTime,
                  )));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Seleccionar Mascota', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard({
    required int minutes,
    required double multiplier,
    required double displayPrice, // ✅ Nuevo parámetro
    required bool isSelected,
    required VoidCallback onTap,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300, width: isSelected ? 2.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Radio<int>(
              value: minutes,
              groupValue: _selectedDuration,
              onChanged: (_) => onTap(),
              activeColor: Colors.blue,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$minutes minutos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                      if (isSelected) Icon(Icons.check_circle, color: Colors.blue, size: 24),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$${displayPrice.toStringAsFixed(2)} MXN', // ✅ Mostramos el precio calculado
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.green.shade800 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}