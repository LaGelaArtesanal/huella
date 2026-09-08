import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/call_service.dart';
import '../services/call_audio_service.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String walkId;
  final bool isCaller;
  final String otherUserName;
  final String otherUserId;
  final String currentUserId;
  final bool isVideoCall;
  final bool isWalker;

  const CallScreen({
    super.key,
    required this.callId,
    required this.walkId,
    required this.isCaller,
    required this.otherUserName,
    required this.otherUserId,
    required this.currentUserId,
    required this.isVideoCall,
    required this.isWalker,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  final CallAudioService _audioService = CallAudioService();

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isConnected = false;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isRinging = false;
  bool _isInitializing = true;
  bool _hasRemoteVideo = false;
  bool _isSpeakerOn = true;

  // ✅ Bandera de seguridad para evitar llamadas recursivas a _endCall
  bool _isEnding = false;

  StreamSubscription<DocumentSnapshot>? _callStatusSubscription;

  @override
  void initState() {
    super.initState();
    _initCall();
    _listenToCallStatus();
  }

  void _listenToCallStatus() {
    _callStatusSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;

      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'];

      if ((status == 'ended' || status == 'rejected') && !_isEnding) {
        print('📞 Firestore detectó estado: $status. Colgando llamada...');
        _endCall();
      }
    });
  }

  Future<void> _initCall() async {
    try {
      print('📞 Iniciando llamada - callId: ${widget.callId}, isCaller: ${widget.isCaller}');

      // 1. Solicitar permisos
      var cameraStatus = await Permission.camera.request();
      var micStatus = await Permission.microphone.request();

      if (cameraStatus.isDenied || micStatus.isDenied) {
        print('❌ Permisos de cámara o micrófono denegados');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se necesitan permisos de Cámara y Micrófono. Revísalos en Ajustes.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
      print('✅ Permisos concedidos');

      // 2. Sonido de llamada para el receptor
      if (!widget.isCaller) {
        setState(() => _isRinging = true);
        await _audioService.playRingtone();
      }

      // 3. Inicializar renderizadores y servicio
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _callService.initialize(isVideoCall: widget.isVideoCall);

      // 4. Activar altavoz por defecto
      try {
        await Helper.setSpeakerphoneOn(true);
        _isSpeakerOn = true;
        print('🔊 Altavoz activado');
      } catch (e) {
        print('⚠️ No se pudo activar el altavoz automáticamente: $e');
      }

      // 5. Asignar stream local al renderizador
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = _callService.localStream;
          _isInitializing = false;
        });
      }

      // 6. Escuchar stream remoto
      _callService.onRemoteStreamReceived = (stream) {
        if (mounted) {
          print('📥 ¡Stream remoto recibido!');
          setState(() {
            _remoteRenderer.srcObject = stream;
            _isConnected = true;
            _isRinging = false;
            _hasRemoteVideo = widget.isVideoCall && (stream?.getVideoTracks().isNotEmpty ?? false);
          });
          _audioService.stopRingtone();
        }
      };

      // 7. Crear oferta o responder
      if (widget.isCaller) {
        print('📡 Creando oferta...');
        await _callService.createOffer(widget.callId, widget.currentUserId);
      } else {
        print('📡 Respondiendo llamada...');
        await _callService.answerCall(widget.callId, widget.currentUserId);
      }
    } catch (e) {
      print('❌ Error al inicializar la llamada: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al conectar: $e'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _endCall() async {
    if (_isEnding) {
      print('⚠️ _endCall ya está en progreso, ignorando.');
      return;
    }

    _isEnding = true;
    print('🛑 Colgando llamada...');

    try {
      await _audioService.stopRingtone();
      await _callService.hangUp(widget.callId);
      print('✅ Llamada finalizada en Firestore');
    } catch (e) {
      print('⚠️ Error al ejecutar hangUp: $e');
    } finally {
      if (mounted) {
        // ✅ Usar pop() simple es más seguro que popUntil en este contexto
        Navigator.of(context).pop();
      }
    }
  }

  void _toggleVideo() {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    _callService.toggleVideo(_isVideoEnabled);
  }

  void _toggleAudio() {
    setState(() => _isAudioEnabled = !_isAudioEnabled);
    _callService.toggleAudio(_isAudioEnabled);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              const SizedBox(height: 24),
              Text('Conectando...', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        print('🔙 Botón atrás presionado. Colgando...');
        await _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Fondo: Video remoto o Avatar
            if (widget.isVideoCall && _hasRemoteVideo)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        child: Text(
                          widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 60, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.otherUserName,
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isConnected ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isConnected ? '🟢 En llamada' : (_isRinging ? '🔔 Llamando...' : '⏳ Conectando...'),
                          style: TextStyle(
                            color: _isConnected ? Colors.green.shade300 : Colors.orange.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Picture in Picture: Video local (solo si es videollamada)
            if (widget.isVideoCall)
              Positioned(
                top: 60,
                right: 20,
                width: 110,
                height: 150,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _localRenderer.srcObject != null
                        ? RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                        : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  ),
                ),
              ),

            // Barra superior con nombre y estado
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.otherUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isConnected ? 'Conectado' : (_isRinging ? 'Llamando...' : 'Conectando...'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Controles inferiores
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 50, top: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isVideoCall)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ControlButton(
                            icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
                            color: _isAudioEnabled ? Colors.white.withOpacity(0.2) : Colors.red,
                            label: _isAudioEnabled ? 'Mic On' : 'Mic Off',
                            onPressed: _toggleAudio,
                          ),
                          const SizedBox(width: 32),
                          _ControlButton(
                            icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                            color: _isVideoEnabled ? Colors.white.withOpacity(0.2) : Colors.red,
                            label: _isVideoEnabled ? 'Cam On' : 'Cam Off',
                            onPressed: _toggleVideo,
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ControlButton(
                            icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
                            color: _isAudioEnabled ? Colors.white.withOpacity(0.2) : Colors.red,
                            label: _isAudioEnabled ? 'Mic On' : 'Mic Off',
                            onPressed: _toggleAudio,
                          ),
                          const SizedBox(width: 32),
                          _ControlButton(
                            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                            color: _isSpeakerOn ? Colors.white.withOpacity(0.2) : Colors.red,
                            label: _isSpeakerOn ? 'Altavoz' : 'Auricular',
                            onPressed: () async {
                              try {
                                _isSpeakerOn = !_isSpeakerOn;
                                await Helper.setSpeakerphoneOn(_isSpeakerOn);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_isSpeakerOn ? '🔊 Altavoz activado' : '🔈 Auricular activado'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              } catch (e) {
                                print('Error al cambiar altavoz: $e');
                              }
                            },
                          ),
                        ],
                      ),

                    const SizedBox(height: 40),

                    // Botón de colgar
                    GestureDetector(
                      onTap: () {
                        print('🔴 Usuario tocó el botón rojo de colgar.');
                        _endCall();
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.red, blurRadius: 20, offset: Offset(0, 10)),
                          ],
                        ),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Toca para finalizar', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    print('🧹 Dispose de CallScreen ejecutado.');
    _callStatusSubscription?.cancel();
    _audioService.stopRingtone();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callService.dispose();
    _audioService.dispose();
    super.dispose();
  }
}

// Widget reutilizable para los botones de control
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}