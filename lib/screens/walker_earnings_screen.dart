import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/wallet_service.dart';
import 'walk_receipt_screen.dart';
import 'monthly_receipt_screen.dart';

class WalkerEarningsScreen extends StatefulWidget {
  final String walkerId;
  const WalkerEarningsScreen({super.key, required this.walkerId});

  @override
  State<WalkerEarningsScreen> createState() => _WalkerEarningsScreenState();
}

class _WalkerEarningsScreenState extends State<WalkerEarningsScreen> {
  static const List<String> _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    WalletService().releasePendingFunds(widget.walkerId);
  }

  Future<void> _showMonthSelectorDialog() async {
    final now = DateTime.now();
    int? selectedYear = now.year;
    int? selectedMonth = now.month;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Seleccionar Período'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Selecciona el mes y año para generar el recibo:'),
                const SizedBox(height: 16),
                DropdownButton<int>(
                  value: selectedMonth,
                  isExpanded: true,
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(value: month, child: Text(_monthNames[index]));
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  if (selectedMonth != null && selectedYear != null) {
                    Navigator.pop(context, {'month': selectedMonth!, 'year': selectedYear!});
                  }
                },
                child: const Text('Generar'),
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
        showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      }

      try {
        final startDate = DateTime(year, month, 1);
        final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

        final walksSnapshot = await FirebaseFirestore.instance
            .collection('walks')
            .where('walkerId', isEqualTo: widget.walkerId)
            .where('status', isEqualTo: 'completed')
            .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .get();

        if (mounted) Navigator.pop(context);

        if (walksSnapshot.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No hay paseos completados en ${_monthNames[month - 1]} $year.'), backgroundColor: Colors.orange),
            );
          }
        } else {
          final transactions = walksSnapshot.docs.map((doc) {
            final data = doc.data();
            final finalAmount = (data['finalAmount'] as num?)?.toDouble() ?? 0.0;
            final tip = (data['tipAmount'] as num?)?.toDouble() ?? 0.0;
            final grossAmount = finalAmount + tip;

            const commissionPercent = 21.0;
            final platformFee = grossAmount * (commissionPercent / 100);
            final walkerGross = grossAmount - platformFee;

            final isrRetention = walkerGross * 0.10;
            final ivaRetention = walkerGross * 0.08;
            final netAmount = walkerGross - isrRetention - ivaRetention;

            return {
              'walkId': doc.id,
              'grossAmount': grossAmount,
              'tipAmount': tip,
              'netAmount': netAmount,
              'platformFee': platformFee,
              'isrRetention': isrRetention,
              'ivaRetention': ivaRetention,
              'createdAt': data['completedAt'],
              'status': 'completed',
            };
          }).toList();

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MonthlyReceiptScreen(
                  walkerId: widget.walkerId,
                  year: year,
                  month: month,
                  transactions: transactions,
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al generar el recibo: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Mi Billetera', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'Generar recibo mensual',
            onPressed: _showMonthSelectorDialog,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('wallets').doc(widget.walkerId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Aún no tienes ganancias registradas', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final availableBalance = (data['availableBalance'] as num?)?.toDouble() ?? 0.0;
          final pendingBalance = (data['pendingBalance'] as num?)?.toDouble() ?? 0.0;
          final totalTaxRetained = (data['totalTaxRetained'] as num?)?.toDouble() ?? 0.0;
          final transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    Text('Saldo Disponible para Retiro', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '\$${availableBalance.toStringAsFixed(2)} MXN',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBalanceChip('Pendiente', pendingBalance, Colors.orange),
                        _buildBalanceChip('Retenciones', totalTaxRetained, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: availableBalance > 50 ? () => _requestWithdrawal(availableBalance) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          availableBalance > 50 ? 'Solicitar Retiro a Cuenta' : 'Mínimo \$50 para retirar',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Historial de Paseos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[transactions.length - 1 - index];
                            final netAmount = (tx['netAmount'] as num?)?.toDouble() ?? 0.0;
                            final status = tx['status'] ?? 'pending';
                            final releaseDate = tx['releaseDate'] != null ? (tx['releaseDate'] as Timestamp).toDate() : null;
                            final walkId = tx['walkId'] ?? '';

                            String statusText = status == 'available' ? '✅ Disponible' : (status == 'withdrawn' ? '💸 Retirado' : '⏳ En Garantía');
                            Color statusColor = status == 'available' ? Colors.green : (status == 'withdrawn' ? Colors.grey : Colors.orange);

                            // ✅ CORRECCIÓN: Reemplazo del ListTile por un Row personalizado para evitar overflow
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: statusColor.withOpacity(0.1),
                                      child: Icon(Icons.pets, color: statusColor, size: 20),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Paseo #${walkId.isNotEmpty ? walkId.substring(0, 6) : 'N/A'}',
                                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Neto: \$${netAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: Colors.black87)),
                                          if (releaseDate != null && status == 'pending') ...[
                                            const SizedBox(height: 2),
                                            Text('Se libera: ${DateFormat('dd/MM/yyyy').format(releaseDate)}', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        // ✅ Usamos InkWell en lugar de IconButton para evitar el padding forzado de 48px
                                        InkWell(
                                          onTap: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => WalkReceiptScreen(transaction: tx)));
                                          },
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(Icons.receipt_long, size: 22, color: Colors.blue),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text('$label: \$${amount.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _requestWithdrawal(double amount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar Retiro'),
        content: Text('¿Deseas retirar \$${amount.toStringAsFixed(2)} MXN a tu cuenta bancaria registrada?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('wallets').doc(widget.walkerId).update({
        'availableBalance': 0.0,
        'lastWithdrawal': FieldValue.serverTimestamp(),
        'lastWithdrawalAmount': amount,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Solicitud de retiro enviada. Recibirás el dinero en 24-48 hrs.'), backgroundColor: Colors.green),
        );
      }
    }
  }
}