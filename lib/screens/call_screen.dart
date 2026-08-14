import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;
  final String otherUserName;
  final String currentUserId;

  const CallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    required this.otherUserName,
    required this.currentUserId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _callService.initialize();

      _localRenderer.srcObject = _callService.localStream;

      _callService.onRemoteStreamReceived = (stream) {
        if (mounted) {
          setState(() {
            _remoteRenderer.srcObject = stream;
            _isConnected = true;
          });
        }
      };

      if (widget.isCaller) {
        await _callService.createOffer(widget.callId, widget.currentUserId);
        FirebaseFirestore.instance.collection('calls').doc(widget.callId).snapshots().listen((doc) {
          if (doc.exists && doc.data()?['status'] == 'connected') {
            _callService.acceptOffer(widget.callId);
          }
        });
      } else {
        await _callService.answerCall(widget.callId, widget.currentUserId);
      }
    } catch (e) {
      print('❌ Error al inicializar la llamada: $e');
    }
  }

  // ✅ FUNCIÓN DE COLGAR INFALIBLE
  Future<void> _endCall() async {
    try {
      // 1. Intentar notificar a Firebase y cerrar WebRTC
      await _callService.hangUp(widget.callId);
    } catch (e) {
      print('⚠️ Error al colgar en el servicio (se cerrará la pantalla de todos modos): $e');
    } finally {
      // 2. Cerrar la pantalla SIEMPRE, haya ocurrido un error o no
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ✅ Evita que el usuario salga con el botón "Atrás" del celular sin colgar correctamente
      onWillPop: () async {
        await _endCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video remoto (pantalla completa)
            Positioned.fill(
              child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
              ),
            ),

            // Video local (ventana pequeña)
            Positioned(
              top: 40,
              right: 20,
              width: 100,
              height: 150,
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12)
                ),
                child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                ),
              ),
            ),

            // Controles inferiores
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                      widget.otherUserName,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))
                      ])
                  ),
                  const SizedBox(height: 8),
                  Text(
                      _isConnected ? '🟢 Conectado' : '🟡 Llamando...',
                      style: const TextStyle(color: Colors.white70, fontSize: 16, shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))
                      ])
                  ),
                  const SizedBox(height: 32),

                  // ✅ BOTÓN DE COLGAR MEJORADO
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.red.shade600,
                    child: IconButton(
                      icon: const Icon(Icons.call_end, color: Colors.white, size: 32),
                      onPressed: _endCall, // Llama a la función infalible
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // ✅ Limpieza segura de recursos de WebRTC para evitar fugas de memoria
    try {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      _localRenderer.dispose();
      _remoteRenderer.dispose();
      _callService.dispose();
    } catch (e) {
      print('Error al liberar recursos de llamada: $e');
    }
    super.dispose();
  }
}