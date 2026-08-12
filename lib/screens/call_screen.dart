import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import faltante
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;
  final String otherUserName;
  final String currentUserId; // Nuevo parámetro requerido

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
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    await _callService.initialize();

    // CORRECCIÓN: Usar srcObject en lugar de addRenderer
    _localRenderer.srcObject = _callService.localStream;

    _callService.onRemoteStreamReceived = (stream) {
      _remoteRenderer.srcObject = stream; // CORRECCIÓN AQUÍ TAMBIÉN
      setState(() => _isConnected = true);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ),
          Positioned(
            top: 40, right: 20, width: 100, height: 150,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(12)),
              child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
          ),
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Column(
              children: [
                Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_isConnected ? 'Conectado' : 'Llamando...', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 32),
                CircleAvatar(
                  radius: 35, backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    onPressed: () async {
                      await _callService.hangUp(widget.callId);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callService.dispose();
    super.dispose();
  }
}