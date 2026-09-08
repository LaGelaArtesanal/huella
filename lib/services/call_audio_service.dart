import 'package:audioplayers/audioplayers.dart';

class CallAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  Future<void> playRingtone() async {
    try {
      // ✅ Configuramos el bucle ANTES de reproducir
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // ✅ La nueva versión requiere pasar el AssetSource dentro de play()
      await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
      _isPlaying = true;
    } catch (e) {
      print('❌ Error al reproducir ringtone: $e');
    }
  }

  Future<void> stopRingtone() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      _isPlaying = false;
    }
  }

  Future<void> playCallSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/call_sound.mp3'));
    } catch (e) {
      print('❌ Error al reproducir sonido de llamada: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}