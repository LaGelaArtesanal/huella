import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

/// Resultado de un intento de pago.
class PaymentOutcome {
  final bool success;
  final bool cancelled;
  final String? paymentIntentId;
  final String? errorMessage;

  const PaymentOutcome._({
    this.success = false,
    this.cancelled = false,
    this.paymentIntentId,
    this.errorMessage,
  });

  const PaymentOutcome.succeeded(String paymentIntentId)
      : success = true,
        cancelled = false,
        paymentIntentId = paymentIntentId,
        errorMessage = null;

  const PaymentOutcome.cancelled()
      : success = false,
        cancelled = true,
        paymentIntentId = null,
        errorMessage = null;

  const PaymentOutcome.failure(String message)
      : success = false,
        cancelled = false,
        paymentIntentId = null,
        errorMessage = message;
}

/// Servicio de pagos con Stripe (Payment Sheet).
class PaymentService {
  PaymentService._internal();
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;

  static const String _functionsRegion = 'us-central1';
  static const String merchantName = 'Huella';

  bool get canUseCard => !kIsWeb;

  /// 1) Crea el PaymentIntent en el backend.
  Future<Map<String, String>> createPaymentIntent({
    required double amount,
    required String currency,
    required String walkId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No hay sesión iniciada para procesar el pago');
    }

    final idToken = await user.getIdToken();
    if (idToken == null) {
      throw Exception('No se pudo obtener el token de autenticación del usuario');
    }

    debugPrint('🔑 ID Token obtenido: ${idToken.substring(0, 20)}...');

    final projectId = Firebase.apps.first.options.projectId;
    final uri = Uri.parse(
      'https://$_functionsRegion-$projectId.cloudfunctions.net/createPaymentIntent',
    );

    debugPrint('💳 Creando PaymentIntent de \$$amount $currency para el paseo $walkId');
    debugPrint('🌐 URL: $uri');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'data': {
          'amount': amount,
          'currency': currency,
          'walkId': walkId,
        }
      }),
    );

    debugPrint('📡 Respuesta HTTP: ${response.statusCode}');
    debugPrint('📦 Body: ${response.body}');

    if (response.statusCode != 200) {
      debugPrint('❌ Cloud Function respondió ${response.statusCode}: ${response.body}');
      throw Exception('Error ${response.statusCode} al crear el intento de pago');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final error = body['error'];
    if (error is Map<String, dynamic> && error['message'] != null) {
      throw Exception(error['message'].toString());
    }

    final result = (body['result'] ?? const {}) as Map;
    final clientSecret = result['clientSecret']?.toString();
    final paymentIntentId = result['paymentIntentId']?.toString();

    debugPrint('🔑 Client Secret recibido: ${clientSecret != null && clientSecret.length > 30 ? clientSecret.substring(0, 30) : clientSecret}...');
    debugPrint('💳 PaymentIntent ID: $paymentIntentId');

    if (clientSecret == null || paymentIntentId == null) {
      throw Exception('La pasarela de pago devolvió una respuesta inválida. Intenta de nuevo.');
    }

    debugPrint('✅ PaymentIntent creado exitosamente: $paymentIntentId');
    return {
      'clientSecret': clientSecret,
      'paymentIntentId': paymentIntentId,
    };
  }

  /// 2) Abre la hoja de pago nativa de Stripe y devuelve el resultado.
  Future<PaymentOutcome> presentPaymentSheet({
    required String clientSecret,
    required String paymentIntentId,
  }) async {
    if (!canUseCard) {
      return const PaymentOutcome.failure(
          'Los pagos con tarjeta solo están disponibles en la app móvil');
    }

    try {
      debugPrint('🎨 Inicializando Payment Sheet...');

      // ✅ SIMPLIFICADO: Stripe maneja nativamente si mostrar o no el botón de GPay.
      // No necesitamos verificarlo manualmente, lo que evita el MissingPluginException.
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: merchantName,
          paymentIntentClientSecret: clientSecret,
          // ✅ Configuración de Google Pay (se mostrará solo si el dispositivo lo soporta)
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'MX',
            currencyCode: 'MXN',
            testEnv: true, // ¡CLAVE para emuladores y pruebas!
          ),
        ),
      );

      debugPrint('✅ Payment Sheet inicializado. Presentando...');

      await Stripe.instance.
      presentPaymentSheet();

      debugPrint('🎉 ¡PAGO EXITOSO! El paymentIntentId es: $paymentIntentId');
      return PaymentOutcome.succeeded(paymentIntentId);

    } on StripeException catch (e) {
      final err = e.error;
      debugPrint('❌ StripeException: ${err.code} - ${err.message}');

      if (err.code == FailureCode.Canceled) {
        debugPrint('🚪 Usuario canceló el pago manualmente');
        return const PaymentOutcome.cancelled();
      }

      debugPrint('💥 Error en el pago: ${err.localizedMessage ?? err.message}');
      return PaymentOutcome.failure(
          err.localizedMessage ?? err.message ?? 'Error en la pasarela de pago');
    } catch (e) {
      debugPrint('❌ Error inesperado: $e');
      return PaymentOutcome.failure('No se pudo procesar el pago: $e');
    }
  }
}