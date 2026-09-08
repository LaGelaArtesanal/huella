package com.fredy.huella

// ✅ Stripe REQUIERE FlutterFragmentActivity (no FlutterActivity).
// Con FlutterActivity, Stripe.applySettings() lanzaba excepción en main()
// y la app se quedaba congelada en el splash en release.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
