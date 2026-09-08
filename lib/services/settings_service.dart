import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/pricing_config.dart';

class SettingsService {
  static Future<void> loadSettings() async {
    print(' [SettingsService] Iniciando carga de configuración...');

    try {
      final docRef = FirebaseFirestore.instance
          .collection('settings')
          .doc('pricing');

      print('🔍 [SettingsService] Buscando documento: ${docRef.path}');

      final doc = await docRef.get();

      if (doc.exists) {
        print('✅ [SettingsService] Documento encontrado');
        print('📄 [SettingsService] Datos: ${doc.data()}');

        final data = doc.data()!;
        if (data['basePrice'] != null) {
          final newPrice = (data['basePrice'] as num).toDouble();
          PricingConfig.basePrice = newPrice;
          print('✅ [SettingsService] Precio base actualizado a: \$${PricingConfig.basePrice}');
        } else {
          print('⚠️ [SettingsService] El campo basePrice no existe en el documento');
        }
      } else {
        print('❌ [SettingsService] Documento NO encontrado. Creando uno por defecto...');
        // Crear el documento si no existe
        await docRef.set({
          'basePrice': 100.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ [SettingsService] Documento creado con basePrice: 100.0');
      }
    } catch (e, stackTrace) {
      print('❌ [SettingsService] Error cargando configuración: $e');
      print('❌ [SettingsService] Stack trace: $stackTrace');
    }

    print('📊 [SettingsService] Precio base final: \$${PricingConfig.basePrice}');
  }
}