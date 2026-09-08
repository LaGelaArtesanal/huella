import 'package:cloud_firestore/cloud_firestore.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Registra un nuevo ingreso en la billetera del paseador tras completar un paseo
  Future<void> processWalkPayment({
    required String walkId,
    required String walkerId,
    required double totalAmount,
    required double platformCommissionPercent, // Ej: 21.0
    required DateTime completedAt,
  }) async {
    try {
      // 1. Cálculos financieros
      final platformFee = totalAmount * (platformCommissionPercent / 100);
      final walkerGrossAmount = totalAmount - platformFee;

      // Retenciones de impuestos (Ejemplo estándar para plataformas en México)
      // ISR: 10% (puede variar si es RESICO, lo dejamos en 10% por defecto)
      // IVA: 8% (retención de IVA)
      // NOTA: Estos porcentajes deben ser validados por un contador.
      const double isrRetentionRate = 0.10;
      const double ivaRetentionRate = 0.08;

      final isrRetention = walkerGrossAmount * isrRetentionRate;
      final ivaRetention = walkerGrossAmount * ivaRetentionRate;
      final totalTaxRetention = isrRetention + ivaRetention;

      final walkerNetAmount = walkerGrossAmount - totalTaxRetention;

      // 2. Fecha de liberación (Semana de Garantía: 7 días después)
      final releaseDate = completedAt.add(const Duration(days: 7));

      // 3. Crear el objeto de la transacción pendiente
      final transaction = {
        'walkId': walkId,
        'grossAmount': walkerGrossAmount,
        'netAmount': walkerNetAmount,
        'platformFee': platformFee,
        'isrRetention': isrRetention,
        'ivaRetention': ivaRetention,
        'releaseDate': Timestamp.fromDate(releaseDate),
        'status': 'pending', // pending -> available -> withdrawn
        'createdAt': Timestamp.fromDate(completedAt),
      };

      // 4. Actualizar la billetera del paseador en Firestore
      final walletRef = _db.collection('wallets').doc(walkerId);

      await _db.runTransaction((transactionHandler) async {
        final walletDoc = await transactionHandler.get(walletRef);

        if (!walletDoc.exists) {
          // Crear billetera si es la primera vez
          transactionHandler.set(walletRef, {
            'walkerId': walkerId,
            'availableBalance': 0.0,
            'pendingBalance': walkerNetAmount,
            'totalEarnedGross': walkerGrossAmount,
            'totalTaxRetained': totalTaxRetention,
            'transactions': [transaction],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Actualizar billetera existente
          final currentData = walletDoc.data() as Map<String, dynamic>;
          final currentPending = (currentData['pendingBalance'] as num?)?.toDouble() ?? 0.0;
          final currentGross = (currentData['totalEarnedGross'] as num?)?.toDouble() ?? 0.0;
          final currentTax = (currentData['totalTaxRetained'] as num?)?.toDouble() ?? 0.0;
          final currentTransactions = List<Map<String, dynamic>>.from(currentData['transactions'] ?? []);

          currentTransactions.add(transaction);

          transactionHandler.update(walletRef, {
            'pendingBalance': currentPending + walkerNetAmount,
            'totalEarnedGross': currentGross + walkerGrossAmount,
            'totalTaxRetained': currentTax + totalTaxRetention,
            'transactions': currentTransactions,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // 5. Actualizar el documento del paseo para marcar que ya fue procesado financieramente
      await _db.collection('walks').doc(walkId).update({
        'financialStatus': 'processed',
        'walkerNetAmount': walkerNetAmount,
        'platformFee': platformFee,
        'isrRetention': isrRetention,  // ✅ Agrega esto
        'ivaRetention': ivaRetention,  // ✅ Agrega esto
      });

      print('✅ Pago procesado para el paseo $walkId. Neto paseador: $walkerNetAmount');
    } catch (e) {
      print('❌ Error procesando pago: $e');
      throw Exception('No se pudo procesar el pago: $e');
    }
  }

  /// Mueve el dinero de "Pendiente" a "Disponible" si ya pasaron los 7 días
  Future<void> releasePendingFunds(String walkerId) async {
    final walletRef = _db.collection('wallets').doc(walkerId);
    final walletDoc = await walletRef.get();

    if (!walletDoc.exists) return;

    final data = walletDoc.data() as Map<String, dynamic>;
    final transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
    final now = DateTime.now();

    double amountToRelease = 0.0;
    bool hasUpdates = false;

    for (var tx in transactions) {
      if (tx['status'] == 'pending') {
        final releaseDate = (tx['releaseDate'] as Timestamp).toDate();
        if (now.isAfter(releaseDate)) {
          tx['status'] = 'available';
          amountToRelease += (tx['netAmount'] as num).toDouble();
          hasUpdates = true;
        }
      }
    }

    if (hasUpdates) {
      final currentPending = (data['pendingBalance'] as num?)?.toDouble() ?? 0.0;
      final currentAvailable = (data['availableBalance'] as num?)?.toDouble() ?? 0.0;

      await walletRef.update({
        'transactions': transactions,
        'pendingBalance': currentPending - amountToRelease,
        'availableBalance': currentAvailable + amountToRelease,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('💰 Fondos liberados para $walkerId: $amountToRelease');
    }
  }
}