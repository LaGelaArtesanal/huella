import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ✅ Importamos excel con alias y ocultamos su Border para evitar conflictos con Flutter
import 'package:excel/excel.dart' as excel hide Border;

class AdminFinancialScreen extends StatefulWidget {
  const AdminFinancialScreen({super.key});

  @override
  State<AdminFinancialScreen> createState() => _AdminFinancialScreenState();
}

class _AdminFinancialScreenState extends State<AdminFinancialScreen> {
  final _commissionController = TextEditingController();
  bool _isSavingCommission = false;
  double _currentCommission = 21.0;

  static const List<String> _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _loadCommission();
  }

  Future<void> _loadCommission() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('financial').get();
      if (doc.exists) {
        setState(() {
          _currentCommission = (doc.data()?['platformCommission'] as num?)?.toDouble() ?? 21.0;
          _commissionController.text = _currentCommission.toString();
        });
      }
    } catch (e) {
      print('Error cargando comisión: $e');
    }
  }

  Future<void> _saveCommission() async {
    final newCommission = double.tryParse(_commissionController.text);
    if (newCommission == null || newCommission < 0 || newCommission > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un porcentaje válido (0-100)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSavingCommission = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('financial').set({
        'platformCommission': newCommission,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Comisión actualizada'), backgroundColor: Colors.green)
        );
        setState(() => _currentCommission = newCommission);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingCommission = false);
    }
  }

  Future<void> _exportToExcel() async {
    final now = DateTime.now();
    int? selectedYear = now.year;
    int? selectedMonth = now.month;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Exportar Reporte a Excel'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Selecciona el mes y año para exportar:'),
                const SizedBox(height: 16),
                DropdownButton<int>(
                  value: selectedMonth,
                  isExpanded: true,
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text(_monthNames[index]),
                    );
                  }),
                  onChanged: (val) => setDialogState(() => selectedMonth = val),
                ),
                const SizedBox(height: 12),
                DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  items: List.generate(2, (index) {
                    final year = now.year - index;
                    return DropdownMenuItem(value: year, child: Text(year.toString()));
                  }),
                  onChanged: (val) => setDialogState(() => selectedYear = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedMonth != null && selectedYear != null) {
                    Navigator.pop(context, {'month': selectedMonth!, 'year': selectedYear!});
                  }
                },
                child: const Text('Exportar'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final month = result['month']!;
      final year = result['year']!;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        print('📊 Iniciando exportación a Excel...');
        final startDate = DateTime(year, month, 1);
        final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

        print('🔍 Buscando paseos del ${DateFormat('dd/MM/yyyy').format(startDate)} al ${DateFormat('dd/MM/yyyy').format(endDate)}');

        final walksSnapshot = await FirebaseFirestore.instance
            .collection('walks')
            .where('status', isEqualTo: 'completed')
            .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .get();

        print('✅ Encontrados ${walksSnapshot.docs.length} paseos.');

        if (walksSnapshot.docs.isEmpty) {
          if (mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No hay paseos completados en ${_monthNames[month - 1]} $year.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        print('📝 Creando archivo Excel...');
        final excelFile = excel.Excel.createExcel();
        final sheet = excelFile['Reporte Huella'];

        final headerStyle = excel.CellStyle(
          bold: true,
          fontSize: 12,
          backgroundColorHex: excel.ExcelColor.fromHexString('#4A148C'),
          fontColorHex: excel.ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: excel.HorizontalAlign.Center,
        );

        final headers = [
          'Fecha', 'Folio Paseo', 'Paseador', 'Dueño', 'Mascota',
          'Monto Base', 'Propina', 'Total Bruto', 'Comisión Plataforma',
          'Ganancia Paseador', 'Retención ISR', 'Retención IVA', 'Neto Paseador',
        ];

        for (var i = 0; i < headers.length; i++) {
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = excel.TextCellValue(headers[i]);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
        }

        int row = 1;
        double totalGross = 0, totalTips = 0, totalPlatformFee = 0;
        double totalWalkerEarnings = 0, totalISR = 0, totalIVA = 0, totalNet = 0;

        for (var doc in walksSnapshot.docs) {
          final data = doc.data();
          final completedAt = data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : DateTime.now();
          final finalAmount = (data['finalAmount'] as num?)?.toDouble() ?? 0.0;
          final tip = (data['tipAmount'] as num?)?.toDouble() ?? 0.0;
          final grossAmount = finalAmount + tip;

          final platformFee = grossAmount * (_currentCommission / 100);
          final walkerGross = grossAmount - platformFee;
          final isrRetention = walkerGross * 0.10;
          final ivaRetention = walkerGross * 0.08;
          final netAmount = walkerGross - isrRetention - ivaRetention;

          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = excel.TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(completedAt));
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = excel.TextCellValue(doc.id);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = excel.TextCellValue(data['walkerName'] ?? 'N/A');
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = excel.TextCellValue(data['ownerName'] ?? 'N/A');
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = excel.TextCellValue(data['petName'] ?? 'N/A');
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = excel.DoubleCellValue(finalAmount);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = excel.DoubleCellValue(tip);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = excel.DoubleCellValue(grossAmount);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = excel.DoubleCellValue(platformFee);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = excel.DoubleCellValue(walkerGross);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = excel.DoubleCellValue(isrRetention);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = excel.DoubleCellValue(ivaRetention);
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = excel.DoubleCellValue(netAmount);

          totalGross += grossAmount;
          totalTips += tip;
          totalPlatformFee += platformFee;
          totalWalkerEarnings += walkerGross;
          totalISR += isrRetention;
          totalIVA += ivaRetention;
          totalNet += netAmount;
          row++;
        }

        row++;
        final totalStyle = excel.CellStyle(
          bold: true,
          fontSize: 12,
          backgroundColorHex: excel.ExcelColor.fromHexString('#E1BEE7'),
          horizontalAlign: excel.HorizontalAlign.Center,
        );

        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = excel.TextCellValue('TOTALES:');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = totalStyle;
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = excel.DoubleCellValue(totalGross);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).cellStyle = totalStyle;
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = excel.DoubleCellValue(totalPlatformFee);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).cellStyle = totalStyle;
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = excel.DoubleCellValue(totalWalkerEarnings);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).cellStyle = totalStyle;
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = excel.DoubleCellValue(totalISR);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).cellStyle = totalStyle;
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = excel.DoubleCellValue(totalIVA);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).cellStyle = totalStyle;
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = excel.DoubleCellValue(totalNet);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).cellStyle = totalStyle;

        for (var i = 0; i < headers.length; i++) {
          sheet.setColumnWidth(i, 15);
        }

        print('💾 Guardando archivo Excel...');
        final bytes = excelFile.save();

        if (bytes == null) {
          throw Exception('No se pudieron generar los bytes del archivo Excel.');
        }

        print('📂 Obteniendo directorio de documentos...');
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'Huella_Reporte_${_monthNames[month - 1]}_$year.xlsx';
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);

        print('📝 Escribiendo archivo en: $filePath');
        await file.writeAsBytes(bytes);
        print('✅ Archivo guardado exitosamente.');

        // ✅ Cerrar el loader antes de compartir
        if (mounted) Navigator.pop(context);

        print('📤 Intentando compartir archivo...');
        try {
          await Share.shareXFiles(
            [XFile(filePath)],
            subject: 'Reporte Huella - ${_monthNames[month - 1]} $year',
            text: 'Reporte financiero de ${_monthNames[month - 1]} $year',
          );
        } catch (shareError) {
          print('⚠️ Error al compartir: $shareError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Archivo guardado en:\n$filePath\n(No se pudo abrir el menú de compartir)'),
                duration: const Duration(seconds: 6),
                backgroundColor: Colors.blue,
              ),
            );
          }
        }

      } catch (e, stackTrace) {
        print('❌ Error al exportar: $e');
        print('❌ Stack trace: $stackTrace');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al exportar: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5)
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: Text('Panel Financiero', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            tooltip: 'Exportar reporte a Excel',
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen Financiero', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('walks')
                  .where('status', isEqualTo: 'completed')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                    child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red.shade700)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
                }

                final walks = snapshot.data?.docs ?? [];
                int totalWalks = walks.length;
                double totalRevenue = 0.0;
                double totalTips = 0.0;
                Set<String> uniqueWalkers = {};

                Map<String, double> dailyRevenue = {};
                for (int i = 6; i >= 0; i--) {
                  final date = DateTime.now().subtract(Duration(days: i));
                  final key = DateFormat('dd/MM').format(date);
                  dailyRevenue[key] = 0.0;
                }

                for (var doc in walks) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = (data['finalAmount'] as num?)?.toDouble() ?? 0.0;
                  final tip = (data['tipAmount'] as num?)?.toDouble() ?? 0.0;
                  final walkerId = data['walkerId'] ?? '';
                  final completedAt = data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null;

                  totalRevenue += amount;
                  totalTips += tip;
                  if (walkerId.isNotEmpty) uniqueWalkers.add(walkerId);

                  if (completedAt != null) {
                    final dateKey = DateFormat('dd/MM').format(completedAt);
                    if (dailyRevenue.containsKey(dateKey)) {
                      dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0.0) + amount + tip;
                    }
                  }
                }

                final platformEarnings = totalRevenue * (_currentCommission / 100);
                final walkersEarnings = totalRevenue - platformEarnings;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ingresos (Últimos 7 días)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: (dailyRevenue.values.reduce((a, b) => a > b ? a : b) * 1.2),
                                barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('\$${rod.toY.toStringAsFixed(0)}', TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                    final keys = dailyRevenue.keys.toList();
                                    if (value.toInt() >= 0 && value.toInt() < keys.length) {
                                      return Padding(padding: const EdgeInsets.only(top: 8), child: Text(keys[value.toInt()], style: TextStyle(fontSize: 10, color: Colors.grey[600])));
                                    }
                                    return const SizedBox.shrink();
                                  })),
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: dailyRevenue.entries.toList().asMap().entries.map((entry) {
                                  return BarChartGroupData(
                                    x: entry.key,
                                    barRods: [BarChartRodData(toY: entry.value.value, color: Colors.purple, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))]),
                            child: Column(
                              children: [
                                Text('Distribución', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 150,
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 40,
                                      sections: [
                                        PieChartSectionData(value: platformEarnings, title: '${_currentCommission.toInt()}%', color: Colors.purple, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                        PieChartSectionData(value: walkersEarnings, title: '${100 - _currentCommission.toInt()}%', color: Colors.green, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(width: 12, height: 12, color: Colors.purple),
                                    const SizedBox(width: 4),
                                    const Text('Plataforma', style: TextStyle(fontSize: 10)),
                                    const SizedBox(width: 12),
                                    Container(width: 12, height: 12, color: Colors.green),
                                    const SizedBox(width: 4),
                                    const Text('Paseadores', style: TextStyle(fontSize: 10)),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _buildMiniStat('Paseos', totalWalks.toString(), Colors.blue),
                              const SizedBox(height: 12),
                              _buildMiniStat('Ingresos', '\$${totalRevenue.toStringAsFixed(0)}', Colors.orange),
                              const SizedBox(height: 12),
                              _buildMiniStat('Propinas', '\$${totalTips.toStringAsFixed(0)}', Colors.amber),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.purple, Colors.purple.shade700]), borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Comisión Plataforma (${_currentCommission.toStringAsFixed(1)}%)', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('\$${platformEarnings.toStringAsFixed(2)} MXN', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Ganancias Paseadores', style: TextStyle(color: Colors.green.shade800, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('\$${walkersEarnings.toStringAsFixed(2)} MXN', style: GoogleFonts.poppins(color: Colors.green.shade900, fontSize: 20, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(height: 32),

                    Text('Configuración', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Porcentaje Plataforma', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: TextField(controller: _commissionController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Comisión (%)', suffixText: '%', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                          const SizedBox(width: 12),
                          ElevatedButton(onPressed: _isSavingCommission ? null : _saveCommission, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white), child: _isSavingCommission ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Guardar')),
                        ]),
                      ]),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  void dispose() {
    _commissionController.dispose();
    super.dispose();
  }
}