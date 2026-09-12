import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class MonthlyReceiptScreen extends StatelessWidget {
  final String walkerId;
  final int year;
  final int month;
  final List<Map<String, dynamic>> transactions;

  const MonthlyReceiptScreen({
    super.key,
    required this.walkerId,
    required this.year,
    required this.month,
    required this.transactions,
  });

  // ✅ Lista de meses en español (SIN LOCALE)
  static const List<String> _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  Future<Uint8List> _generateMonthlyPdf() async {
    final pdf = pw.Document();

    double totalGross = 0;
    double totalTips = 0;
    double totalPlatformFee = 0;
    double totalISR = 0;
    double totalIVA = 0;
    double totalNet = 0;

    // ✅ Usar la lista manual en lugar de DateFormat con locale
    final monthName = _monthNames[month - 1];

    for (var tx in transactions) {
      totalGross += (tx['grossAmount'] as num?)?.toDouble() ?? 0.0;
      totalTips += (tx['tipAmount'] as num?)?.toDouble() ?? 0.0;
      totalPlatformFee += (tx['platformFee'] as num?)?.toDouble() ?? 0.0;
      totalISR += (tx['isrRetention'] as num?)?.toDouble() ?? 0.0;
      totalIVA += (tx['ivaRetention'] as num?)?.toDouble() ?? 0.0;
      totalNet += (tx['netAmount'] as num?)?.toDouble() ?? 0.0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(text: 'Reporte Mensual - Huella', level: 0),
            pw.Text('Paseador ID: $walkerId', style: pw.TextStyle(fontSize: 10)),
            pw.Text('Período: ${_capitalize(monthName)} $year', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('Fecha de emisión: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10)),
            pw.Divider(),
            pw.SizedBox(height: 10),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RESUMEN DEL MES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.SizedBox(height: 5),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Total Paseos Completados:'),
                    pw.Text('${transactions.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Total Propinas Recibidas:'),
                    pw.Text('\$${totalTips.toStringAsFixed(2)} MXN', style: pw.TextStyle(color: PdfColors.green)),
                  ]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Ingreso Bruto Total:'),
                    pw.Text('\$${totalGross.toStringAsFixed(2)} MXN'),
                  ]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Comisiones Plataforma:'),
                    pw.Text('-\$${totalPlatformFee.toStringAsFixed(2)} MXN', style: pw.TextStyle(color: PdfColors.red)),
                  ]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Retenciones ISR + IVA:'),
                    pw.Text('-\$${(totalISR + totalIVA).toStringAsFixed(2)} MXN', style: pw.TextStyle(color: PdfColors.red)),
                  ]),
                  pw.Divider(),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('TOTAL NETO RECIBIDO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('\$${totalNet.toStringAsFixed(2)} MXN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green, fontSize: 14)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Text('DETALLE DE PASEOS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 5),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Fecha', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Folio', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Bruto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Propina', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Neto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                ]),
              ],
            ),

            ...transactions.map((tx) {
              final date = tx['createdAt'] != null
                  ? (tx['createdAt'] as Timestamp).toDate()
                  : DateTime.now();
              final walkId = tx['walkId'] ?? 'N/A';
              final gross = (tx['grossAmount'] as num?)?.toDouble() ?? 0.0;
              final tip = (tx['tipAmount'] as num?)?.toDouble() ?? 0.0;
              final net = (tx['netAmount'] as num?)?.toDouble() ?? 0.0;

              return pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(DateFormat('dd/MM').format(date), style: pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(walkId.substring(0, 8), style: pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('\$${gross.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(tip > 0 ? '\$${tip.toStringAsFixed(2)}' : '-', style: pw.TextStyle(fontSize: 8, color: tip > 0 ? PdfColors.green : PdfColors.black))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('\$${net.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  ]),
                ],
              );
            }).toList(),

            pw.SizedBox(height: 30),
            pw.Text('Este documento es un comprobante interno de Huella.', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey, fontStyle: pw.FontStyle.italic)),
            pw.Text('Válido para fines fiscales y de contabilidad.', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey, fontStyle: pw.FontStyle.italic)),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Usar la lista manual en lugar de DateFormat con locale
    final monthName = _monthNames[month - 1];

    return Scaffold(
      appBar: AppBar(
        title: Text('Recibo Mensual - $monthName $year'),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Usa el botón de compartir en la vista previa')),
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async => await _generateMonthlyPdf(),
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: true,
      ),
    );
  }
}

// Función auxiliar para capitalizar
String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}