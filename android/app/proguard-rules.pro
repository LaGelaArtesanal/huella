# ============================================================
# Reglas de ProGuard/R8 para huella (build release)
# ============================================================

# --- Flutter Stripe ---
# R8 reporta clases internas faltantes del módulo pushProvisioning
# (solo se usan en dispositivos con Tap to Pay, no afectan pagos normales)
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$*
-dontwarn com.stripe.android.pushProvisioning.**

# Clases de Stripe que se cargan por reflexión
-keep class com.stripe.android.** { *; }

# SDK de flutter_stripe (method channels y modelos por reflexión)
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**

# --- Flutter WebRTC ---
# WebRTC usa reflexión para acceder a clases nativas
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# --- Modelos de Firebase/Firestore ---
# Firestore serializa/deserializa por reflexión
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
