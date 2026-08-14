pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // ✅ CAMBIO 1: AGP 8.3.2 (La versión más estable y compatible con Flutter)
    id("com.android.application") version "8.9.1" apply false

    // ✅ CAMBIO 2: Kotlin 1.9.24 (Esta versión específica ARREGLA el bug de Java 25.0.2)
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false

    // ✅ CAMBIO 3: Google Services estable (necesario para Firebase)
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")