import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class AlertService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // ✅ Reproducir sonido de alerta
  static Future<void> playAlertSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alert.mp3'));
    } catch (e) {
      print(' Error reproduciendo sonido: $e');
    }
  }

  // ✅ Vibrar el dispositivo
  static Future<void> vibrateDevice() async {
    try {
      // Vibrar por 500ms
      await HapticFeedback.vibrate();

      // Vibración personalizada (si está disponible)
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.vibrate();
    } catch (e) {
      print(' Error vibrando: $e');
    }
  }

  // ✅ Combinar sonido y vibración
  static Future<void> triggerAlert() async {
    await playAlertSound();
    await vibrateDevice();
  }
}