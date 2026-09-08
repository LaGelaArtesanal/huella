import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class WalkReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const WalkReceiptScreen({super.key, required this.transaction});

  Future<Uint8List> _generatePdfBytes() async {
    final pdf = pw.Document();

    final walkId = transaction['walkId'] ?? 'N/A';
    final netAmount = (transaction['netAmount'] as num?)?.toDouble() ?? 0.0;
    final grossAmount = (transaction['grossAmount'] as num?)?.toDouble() ?? 0.0;
    final platformFee = (transaction['platformFee'] as num?)?.toDouble() ?? 0.0;
    final isr = (transaction['isrRetention'] as num?)?.toDouble() ?? 0.0;
    final iva = (transaction['ivaRetention'] as num?)?.toDouble() ?? 0.0;

    // ✅ Obtener la propina si existe
    final tip = (transaction['tipAmount'] as num?)?.toDouble() ?? 0.0;
    final baseAmount = grossAmount - tip; // Monto base sin propina

    DateTime date = DateTime.now();
    if (transaction['createdAt'] != null) {
      date = (transaction['createdAt'] as Timestamp).toDate();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(text: 'Recibo de Pago - Huella', level: 0),
              pw.SizedBox(height: 20),
              pw.Text('Folio de Paseo: $walkId'),
              pw.Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}'),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Text('Desglose Financiero', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              // ✅ Mostrar monto base del paseo
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Monto Base del Servicio:'),
                pw.Text('\$${baseAmount.toStringAsFixed(2)} MXN')
              ]),

              // ✅ Mostrar propina por separado (si existe) con color verde
              if (tip > 0) ...[
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Propina del Cliente:'),
                  pw.Text('+ \$${tip.toStringAsFixed(2)} MXN', style: pw.TextStyle(color: PdfColors.green, fontWeight: pw.FontWeight.bold))
                ]),
              ],

              // Línea de total bruto
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total Bruto:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('\$${grossAmount.toStringAsFixed(2)} MXN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
              ]),
              pw.Divider(),

              pw.SizedBox(height: 10),
              pw.Text('Retenciones y Comisiones', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Comisión Plataforma (21%):'),
                pw.Text('- \$${platformFee.toStringAsFixed(2)} MXN', style: pw.TextStyle(color: PdfColors.red400))
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Retención ISR (10%):'),
                pw.Text('- \$${isr.toStringAsFixed(2)} MXN', style: pw.TextStyle(color: PdfColors.red400))
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Retención IVA (8%):'),
                pw.Text('- \$${iva.toStringAsFixed(2)} MXN', style: pw.TextStyle(color: PdfColors.red400))
              ]),

              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL NETO A RECIBIR:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Text('\$${netAmount.toStringAsFixed(2)} MXN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green700))
              ]),

              pw.SizedBox(height: 40),
              pw.Text('Este documento es un comprobante interno de Huella.', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              pw.Text('Las retenciones de ISR e IVA se calculan únicamente sobre el monto base del servicio, no sobre las propinas, conforme al Régimen de Plataformas Tecnológicas del SAT.', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey, fontStyle: pw.FontStyle.italic)),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recibo del Paseo'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PdfPreview(
        build: (format) async => await _generatePdfBytes(),
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: true,
      ),
    );
  }
}